import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/kds_server_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = null;
  });

  group('Complete Order Sync Tests between Host and KDS', () {
    test('Host completing an order broadcasts ORDER_STATUS_UPDATE and SYNC_ORDERS to KDS client', () async {
      final provider = PosProvider();
      while (!provider.isLoaded) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      final item = provider.menuItems.first;

      // Start KDS server on ephemeral port
      await provider.kdsServer.stop();
      await provider.kdsServer.start(
        port: 0,
        getOrdersCallback: () => provider.activeKdsOrders.map((o) => {
          'id': o.id,
          'orderNumber': o.orderNumber,
          'status': o.status.name,
        }).toList(),
        onStatusUpdate: (id, status) {
          provider.updateOrderStatus(id, OrderStatus.values.firstWhere((s) => s.name == status));
        },
      );

      final port = provider.kdsServer.port;

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 1');
      provider.addToCart(item, quantity: 1);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      provider.updateOrderStatus(order.id, OrderStatus.ready);

      // Connect KDS client via WebSocket with PIN
      final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws?pin=1234');
      final receivedMessages = <Map<String, dynamic>>[];
      ws.listen((data) {
        try {
          receivedMessages.add(jsonDecode(data as String) as Map<String, dynamic>);
        } catch (_) {}
      });

      await Future.delayed(const Duration(milliseconds: 200));
      receivedMessages.clear();

      // Host completes the order
      provider.updateOrderStatus(order.id, OrderStatus.completed);

      await Future.delayed(const Duration(milliseconds: 300));

      print('Received messages after host complete: $receivedMessages');

      expect(receivedMessages.any((m) => m['type'] == 'ORDER_STATUS_UPDATE' && m['status'] == 'completed'), isTrue);
      expect(receivedMessages.any((m) => m['type'] == 'SYNC_ORDERS'), isTrue);

      final lastSync = receivedMessages.lastWhere((m) => m['type'] == 'SYNC_ORDERS');
      final activeList = lastSync['orders'] as List;
      expect(activeList.any((o) => o['id'] == order.id), isFalse);

      await ws.close();
      await provider.kdsServer.stop();
    });

    test('KDS client completing an order updates Host POS and removes from active queue', () async {
      final provider = PosProvider();
      while (!provider.isLoaded) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      final item = provider.menuItems.first;

      await provider.kdsServer.stop();
      await provider.kdsServer.start(
        port: 0,
        getOrdersCallback: () => provider.activeKdsOrders.map((o) => {
          'id': o.id,
          'orderNumber': o.orderNumber,
          'status': o.status.name,
        }).toList(),
        onStatusUpdate: (id, status) {
          provider.updateOrderStatus(id, OrderStatus.values.firstWhere((s) => s.name == status));
        },
      );

      final port = provider.kdsServer.port;

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 2');
      provider.addToCart(item, quantity: 1);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      provider.updateOrderStatus(order.id, OrderStatus.ready);
      expect(provider.activeKdsOrders.length, 1);

      // Connect KDS client
      final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws?pin=1234');
      await Future.delayed(const Duration(milliseconds: 200));

      // KDS client clicks "Complete Order"
      ws.add(jsonEncode({
        'action': 'update_status',
        'orderId': order.id,
        'status': 'completed',
        'pin': '1234',
      }));

      await Future.delayed(const Duration(milliseconds: 300));

      print('Host order status after KDS complete: ${provider.orders.first.status}');
      expect(provider.orders.first.status, OrderStatus.completed);
      expect(provider.activeKdsOrders.isEmpty, isTrue);

      await ws.close();
      await provider.kdsServer.stop();
    });

    test('KDS client completing an order via HTTP POST update-status API updates Host POS', () async {
      final provider = PosProvider();
      while (!provider.isLoaded) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      final item = provider.menuItems.first;

      await provider.kdsServer.stop();
      await provider.kdsServer.start(
        port: 0,
        getOrdersCallback: () => provider.activeKdsOrders.map((o) => {
          'id': o.id,
          'orderNumber': o.orderNumber,
          'status': o.status.name,
        }).toList(),
        onStatusUpdate: (id, status) {
          provider.updateOrderStatus(id, OrderStatus.values.firstWhere((s) => s.name == status));
        },
      );

      final port = provider.kdsServer.port;

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 3');
      provider.addToCart(item, quantity: 1);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      provider.updateOrderStatus(order.id, OrderStatus.ready);
      expect(provider.activeKdsOrders.length, 1);

      // Complete via HTTP POST fallback
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('http://127.0.0.1:$port/api/orders/update-status'));
      req.headers.contentType = ContentType.json;
      req.headers.set('X-Barista-Pin', '1234');
      req.write(jsonEncode({
        'orderId': order.id,
        'status': 'completed',
        'pin': '1234',
      }));
      final resp = await req.close();
      final body = await utf8.decoder.bind(resp).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      expect(resp.statusCode, 200);
      expect(json['success'], isTrue);
      expect(provider.orders.first.status, OrderStatus.completed);
      expect(provider.activeKdsOrders.isEmpty, isTrue);

      client.close();
      await provider.kdsServer.stop();
    });

    test('KDS client completing an order using orderNumber string updates Host POS correctly', () async {
      final provider = PosProvider();
      while (!provider.isLoaded) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      final item = provider.menuItems.first;

      await provider.kdsServer.stop();
      await provider.kdsServer.start(
        port: 0,
        getOrdersCallback: () => provider.activeKdsOrders.map((o) => {
          'id': o.id,
          'orderNumber': o.orderNumber,
          'status': o.status.name,
        }).toList(),
        onStatusUpdate: (id, status) {
          provider.updateOrderStatus(id, OrderStatus.values.firstWhere((s) => s.name == status));
        },
      );

      final port = provider.kdsServer.port;

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 4');
      provider.addToCart(item, quantity: 1);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      provider.updateOrderStatus(order.id, OrderStatus.ready);

      final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws?pin=1234');
      await Future.delayed(const Duration(milliseconds: 200));

      // Send orderNumber (e.g. #1) instead of order.id
      ws.add(jsonEncode({
        'action': 'update_status',
        'orderNumber': order.orderNumber,
        'status': 'completed',
        'pin': '1234',
      }));

      await Future.delayed(const Duration(milliseconds: 300));

      expect(provider.orders.first.status, OrderStatus.completed);
      expect(provider.activeKdsOrders.isEmpty, isTrue);

      await ws.close();
      await provider.kdsServer.stop();
    });
  });
}
