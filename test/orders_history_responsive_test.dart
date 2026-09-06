import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/screens/orders_history_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  for (final size in [
    const Size(320, 640),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(768, 1024),
    const Size(1280, 800),
  ]) {
    testWidgets('Test OrdersHistoryScreen layout on screen size ${size.width}x${size.height}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final provider = PosProvider();
      final firstItem = provider.menuItems.first;

      final order = provider.submitCustomerSelfOrder(
        tableNumber: 'Table 01',
        customerName: 'Guest',
        items: [
          OrderItem(
            id: 'item_test_1',
            menuItem: firstItem,
            quantity: 2,
          ),
        ],
        paymentMethod: PaymentMethod.cash,
      );

      provider.updateOrderStatus(order.id, OrderStatus.completed);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<PosProvider>.value(
            value: provider,
            child: const Scaffold(
              body: OrdersHistoryScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Order History'), findsOneWidget);
      expect(find.text('Feedback (0)'), findsOneWidget);
      expect(find.text('Start at #1'), findsOneWidget);
      expect(find.text('Clear History'), findsOneWidget);
    });
  }
}
