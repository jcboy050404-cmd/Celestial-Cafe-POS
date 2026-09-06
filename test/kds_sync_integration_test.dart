import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/kds_server_service.dart';
import 'package:celestial_pos/services/web_templates/kds_web_template.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KDS & Host POS Sync Core Unit Tests', () {
    test('OrderStatus alias resolution and remote KDS status updates', () {
      final provider = PosProvider();
      final friesItem = provider.menuItems.firstWhere(
        (i) => i.isKitchenDish || i.name.toLowerCase().contains('fries'),
      );

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 10');
      provider.addToCart(friesItem, quantity: 2);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      expect(order.status, OrderStatus.confirmed);

      // 1. Alias 'brewing' -> preparing
      provider.updateOrderStatus(order.id, OrderStatus.preparing);
      expect(provider.activeKdsOrders.first.status, OrderStatus.preparing);

      // 2. Alias 'ready' -> ready
      provider.updateOrderStatus(order.id, OrderStatus.ready);
      expect(provider.activeKdsOrders.first.status, OrderStatus.ready);

      // 3. Status 'completed' -> completed
      provider.updateOrderStatus(order.id, OrderStatus.completed);
      expect(provider.activeKdsOrders.isEmpty, isTrue);
    });

    test('Order lookup by ID, formatted orderNumber (#1), and stripped orderNumber (1)', () {
      final provider = PosProvider();
      final friesItem = provider.menuItems.firstWhere(
        (i) => i.isKitchenDish || i.name.toLowerCase().contains('fries'),
      );

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 5');
      provider.addToCart(friesItem, quantity: 1);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      final orderNumStr = order.orderNumber; // e.g. "#1"
      final bareNumStr = orderNumStr.replaceAll('#', '').trim(); // e.g. "1"

      // Advance to preparing using stripped order number
      provider.updateOrderStatus(bareNumStr, OrderStatus.preparing);
      expect(order.status, OrderStatus.preparing);

      // Toggle item prepared using formatted orderNumber
      provider.toggleOrderItemPrepared(orderNumStr, 0);
      expect(order.items[0].isPrepared, isTrue);

      // Set item prepared false using bare order number
      provider.setOrderItemPrepared(bareNumStr, 0, false);
      expect(order.items[0].isPrepared, isFalse);

      // Cancel order using bare order number
      provider.cancelOrder(bareNumStr);
      expect(order.status, OrderStatus.cancelled);
    });

    test('Toggling or setting item prepared on confirmed order auto-advances status to preparing', () {
      final provider = PosProvider();
      final friesItem = provider.menuItems.firstWhere(
        (i) => i.isKitchenDish || i.name.toLowerCase().contains('fries'),
      );

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 7');
      provider.addToCart(friesItem, quantity: 1);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      expect(order.status, OrderStatus.confirmed);
      expect(order.items[0].isPrepared, isFalse);

      // When barista/cook prepares an item from confirmed queue
      provider.toggleOrderItemPrepared(order.id, 0);

      expect(order.items[0].isPrepared, isTrue);
      expect(order.status, OrderStatus.preparing);
    });
  });

  group('KDS Server WebSocket Live Integration Tests', () {
    late KdsServerService server;
    late int serverPort;

    setUp(() async {
      server = KdsServerService();
      // Bind to ephemeral port
      await server.start(
        port: 0,
        getOrdersCallback: () => [
          {
            'id': 'test-ord-1',
            'orderNumber': '#101',
            'status': 'confirmed',
            'tableNumber': 'Table 1',
            'orderType': 'dineIn',
            'items': [
              {
                'name': 'French Fries',
                'quantity': 1,
                'isPrepared': false,
                'isKitchen': true,
              }
            ],
          }
        ],
        onStatusUpdate: (id, status) {},
      );
      serverPort = server.port;
    });

    tearDown(() async {
      await server.stop();
    });

    test('WebSocket client dynamically authenticates with PIN and receives SYNC_ORDERS', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$serverPort/ws');
      final receivedMessages = <Map<String, dynamic>>[];

      ws.listen((data) {
        try {
          receivedMessages.add(jsonDecode(data as String) as Map<String, dynamic>);
        } catch (_) {}
      });

      // Send auth action with default barista PIN '1234'
      ws.add(jsonEncode({
        'action': 'auth',
        'pin': '1234',
      }));

      // Wait briefly for server round-trip
      await Future.delayed(const Duration(milliseconds: 300));

      expect(receivedMessages.any((m) => m['type'] == 'AUTH_SUCCESS'), isTrue);
      expect(receivedMessages.any((m) => m['type'] == 'SYNC_ORDERS'), isTrue);

      final syncMsg = receivedMessages.firstWhere((m) => m['type'] == 'SYNC_ORDERS');
      expect((syncMsg['orders'] as List).isNotEmpty, isTrue);

      await ws.close();
    });

    test('WebSocket client can request sync_orders heartbeat', () async {
      // Connect directly with ?pin=1234
      final ws = await WebSocket.connect('ws://127.0.0.1:$serverPort/ws?pin=1234');
      final receivedMessages = <Map<String, dynamic>>[];

      ws.listen((data) {
        try {
          receivedMessages.add(jsonDecode(data as String) as Map<String, dynamic>);
        } catch (_) {}
      });

      await Future.delayed(const Duration(milliseconds: 200));
      receivedMessages.clear();

      // Trigger heartbeat
      ws.add(jsonEncode({
        'action': 'sync_orders',
        'pin': '1234',
      }));

      await Future.delayed(const Duration(milliseconds: 200));

      expect(receivedMessages.any((m) => m['type'] == 'SYNC_ORDERS'), isTrue);

      await ws.close();
    });

    test('WebSocket dispatches toggle_item_prep and update_status to callbacks', () async {
      String? updatedOrderId;
      String? updatedStatus;
      String? prepOrderId;
      int? prepItemIndex;
      bool? prepIsPrepared;

      server.onOrderStatusUpdate = (id, status) {
        updatedOrderId = id;
        updatedStatus = status;
      };

      server.onOrderItemPrepared = (id, idx, isPrep) {
        prepOrderId = id;
        prepItemIndex = idx;
        prepIsPrepared = isPrep;
      };

      final ws = await WebSocket.connect('ws://127.0.0.1:$serverPort/ws?pin=1234');
      await Future.delayed(const Duration(milliseconds: 100));

      // 1. Test update_status
      ws.add(jsonEncode({
        'action': 'update_status',
        'orderId': 'test-ord-1',
        'status': 'preparing',
        'pin': '1234',
      }));

      // 2. Test toggle_item_prep
      ws.add(jsonEncode({
        'action': 'toggle_item_prep',
        'orderId': 'test-ord-1',
        'itemIndex': 0,
        'isPrepared': true,
        'pin': '1234',
      }));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(updatedOrderId, 'test-ord-1');
      expect(updatedStatus, 'preparing');
      expect(prepOrderId, 'test-ord-1');
      expect(prepItemIndex, 0);
      expect(prepIsPrepared, true);

      await ws.close();
    });
  });

  group('KDS Web Template Contract Verification', () {
    test('Template contains ORDER_STATUS_UPDATE handler with resilient ID matching', () {
      expect(kdsHtmlTemplate.contains("ORDER_STATUS_UPDATE"), isTrue);
      expect(kdsHtmlTemplate.contains("oId === cleanNum"), isTrue);
      expect(kdsHtmlTemplate.contains("AUTH_REQUIRED"), isTrue);
    });

    test('Template contains ITEM_PREPARED handler with status update support', () {
      expect(kdsHtmlTemplate.contains("data.type === 'ITEM_PREPARED'"), isTrue);
      expect(kdsHtmlTemplate.contains("order.status = data.status"), isTrue);
    });

    test('Template includes dynamic auth and periodic heartbeat sync', () {
      expect(kdsHtmlTemplate.contains("action: 'auth'"), isTrue);
      expect(kdsHtmlTemplate.contains("action: 'sync_orders'"), isTrue);
      expect(kdsHtmlTemplate.contains("lockKds()"), isTrue);
    });
  });
}
