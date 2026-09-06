import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/web_templates/kds_web_template.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KDS Kitchen View Aggregation & Preparation Tests', () {
    test('French Fries across multiple tables aggregate to total order quantity (e.g. 5x total)', () {
      final provider = PosProvider();

      // Find fries or a kitchen item
      final friesItem = provider.menuItems.firstWhere(
        (i) => i.name.toLowerCase().contains('fries') || i.isKitchenDish,
      );

      // Order 1: Table 1 with 2x Fries
      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 1');
      provider.addToCart(friesItem, quantity: 2);
      final order1 = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      // Order 2: Table 3 with 1x Fries
      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 3');
      provider.addToCart(friesItem, quantity: 1);
      final order2 = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      // Order 3: Takeout with 2x Fries
      provider.clearCart();
      provider.setOrderType(OrderType.takeaway);
      provider.addToCart(friesItem, quantity: 2);
      final order3 = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      final activeOrders = provider.activeKdsOrders;
      expect(activeOrders.length, 3);
      expect(order1.status, OrderStatus.confirmed);
      expect(order2.status, OrderStatus.confirmed);
      expect(order3.status, OrderStatus.confirmed);

      // Aggregate item quantities across tables
      int totalFriesCount = 0;
      final List<Map<String, dynamic>> tableBreakdown = [];

      for (final order in activeOrders) {
        for (final item in order.items) {
          if (item.menuItem.name == friesItem.name) {
            totalFriesCount += item.quantity;
            tableBreakdown.add({
              'table': order.tableNumber ?? 'Takeout',
              'orderNumber': order.orderNumber,
              'quantity': item.quantity,
              'isPrepared': item.isPrepared,
            });
          }
        }
      }

      // Assert total quantity matches 2 + 1 + 2 = 5
      expect(totalFriesCount, 5);
      expect(tableBreakdown.length, 3);
      final t1 = tableBreakdown.firstWhere((e) => e['table'] == 'Table 1');
      final t3 = tableBreakdown.firstWhere((e) => e['table'] == 'Table 3');
      final to = tableBreakdown.firstWhere((e) => e['table'] == 'Takeout');
      expect(t1['quantity'], 2);
      expect(t3['quantity'], 1);
      expect(to['quantity'], 2);
    });

    test('setOrderItemPrepared auto-advances confirmed order to preparing status', () {
      final provider = PosProvider();
      final dishItem = provider.menuItems.firstWhere((i) => i.isKitchenDish);

      provider.clearCart();
      provider.setOrderType(OrderType.dineIn);
      provider.setTableNumber('Table 2');
      provider.addToCart(dishItem, quantity: 2);
      final order = provider.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      // Initially confirmed
      expect(order.status, OrderStatus.confirmed);
      expect(order.items.first.isPrepared, isFalse);

      // Kitchen cook marks item prepared
      provider.setOrderItemPrepared(order.id, 0, true);

      final updatedOrder = provider.orders.firstWhere((o) => o.id == order.id);
      expect(updatedOrder.status, OrderStatus.preparing);
      expect(updatedOrder.items.first.isPrepared, isTrue);
    });

    test('KDS Live Web Template contains Kitchen View tab and aggregation functions', () {
      expect(kdsHtmlTemplate.contains('🍳 Kitchen View'), isTrue);
      expect(kdsHtmlTemplate.contains('id="kitchenSummaryContainer"'), isTrue);
      expect(kdsHtmlTemplate.contains('function renderKitchenSummary'), isTrue);
      expect(kdsHtmlTemplate.contains('function toggleItemPrepFromSummary'), isTrue);
      expect(kdsHtmlTemplate.contains('function markAllItemPrep'), isTrue);
      expect(kdsHtmlTemplate.contains('ksummary-toolbar'), isTrue);
      expect(kdsHtmlTemplate.contains('ksummary-card'), isTrue);
    });

    test('KDS Live Web Template uses pure black background, mobile responsive layout, and zero neon glow effects', () {
      // 1. Black Background
      expect(kdsHtmlTemplate.contains('--bg-dark: #000000;'), isTrue);
      expect(kdsHtmlTemplate.contains('background-color: #000000 !important;'), isTrue);
      expect(kdsHtmlTemplate.contains('header {\n      background: #000000;'), isTrue);

      // 2. Mobile View Responsive Media Queries
      expect(kdsHtmlTemplate.contains('@media (max-width: 680px)'), isTrue);
      expect(kdsHtmlTemplate.contains('@media (max-width: 400px)'), isTrue);
      expect(kdsHtmlTemplate.contains('zoom-text-label'), isTrue);

      // 3. Zero Neon Effects
      expect(kdsHtmlTemplate.contains('0 0 15px'), isFalse);
      expect(kdsHtmlTemplate.contains('0 0 18px'), isFalse);
      expect(kdsHtmlTemplate.contains('0 0 45px'), isFalse);
      expect(kdsHtmlTemplate.contains('liquidShimmer'), isFalse);
    });
  });
}
