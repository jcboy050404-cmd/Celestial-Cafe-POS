import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/screens/kds_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Clicking Complete & Hand Over immediately completes the order and removes from active queue', (tester) async {
    final provider = PosProvider();
    final item = provider.menuItems.first;

    provider.clearCart();
    provider.setOrderType(OrderType.dineIn);
    provider.setTableNumber('Table 1');
    provider.addToCart(item, quantity: 1);
    final order = provider.completeCheckout(
      paymentMethod: PaymentMethod.cash,
      amountTendered: 500.0,
    );

    // Advance to ready
    provider.updateOrderStatus(order.id, OrderStatus.ready);
    expect(order.status, OrderStatus.ready);
    expect(provider.readyOrders.length, 1);

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const Scaffold(
            body: KdsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find "Complete & Hand Over" button
    final completeBtn = find.text('Complete & Hand Over');
    expect(completeBtn, findsOneWidget);

    // 1-Tap "Complete & Hand Over" directly completes the order without any blocking dialog!
    await tester.tap(completeBtn);
    await tester.pumpAndSettle();

    // Check that order is immediately completed and removed from active KDS queue
    expect(provider.orders.first.status, OrderStatus.completed);
    expect(provider.activeKdsOrders.isEmpty, isTrue);

    // SnackBar with UNDO action is shown
    expect(find.text('Order ${order.orderNumber} completed & handed over!'), findsOneWidget);
    expect(find.text('UNDO'), findsOneWidget);

    // Test UNDO restores the order back to ready
    await tester.tap(find.text('UNDO'));
    await tester.pumpAndSettle();
    expect(provider.orders.first.status, OrderStatus.ready);
    expect(provider.readyOrders.length, 1);
  });

  testWidgets('Clicking Trash can icon opens dialog and allows Void & Restock or Delete Permanently', (tester) async {
    final provider = PosProvider();
    final item = provider.menuItems.first;

    provider.clearCart();
    provider.setOrderType(OrderType.dineIn);
    provider.setTableNumber('Table 1');
    provider.addToCart(item, quantity: 1);
    final order = provider.completeCheckout(
      paymentMethod: PaymentMethod.cash,
      amountTendered: 500.0,
    );
    provider.updateOrderStatus(order.id, OrderStatus.ready);

    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const Scaffold(
            body: KdsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find trash icon button
    final trashBtn = find.byTooltip('Void / Cancel Ticket');
    expect(trashBtn, findsOneWidget);

    // Tap trash icon to open dialog
    await tester.tap(trashBtn);
    await tester.pumpAndSettle();

    expect(find.text('Remove Ticket ${order.orderNumber}?'), findsOneWidget);
    expect(find.text('Void & Restock'), findsOneWidget);
    expect(find.text('Delete Permanently'), findsOneWidget);

    // Test Delete Permanently
    await tester.tap(find.text('Delete Permanently'));
    await tester.pumpAndSettle();

    // Order should be completely deleted from provider
    expect(provider.orders.isEmpty, isTrue);
    expect(provider.activeKdsOrders.isEmpty, isTrue);
  });
}
