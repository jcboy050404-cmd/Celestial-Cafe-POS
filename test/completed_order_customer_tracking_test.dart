import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/screens/customer_online_order_screen.dart';
import 'package:celestial_pos/services/online_order_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Customer Completed Order Tracking & Cache Behavior', () {
    testWidgets('completed order is saved in cache, does not show track order banner, and shows View Receipt in history dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final service = OnlineOrderService();
      const storeId = 'store_completed_test';

      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'owner@test.com',
        storeName: 'Test Cafe',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'item_1',
          name: 'Iced Caramel Macchiato',
          description: 'Espresso with vanilla and caramel drizzle',
          icon: '☕',
          price: 120.0,
          category: ItemCategory.coffee,
        ),
      ];
      await service.publishStoreCatalog(profile: profile, menuItems: menu);

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerOnlineOrderScreen(storeId: storeId),
        ),
      );
      await tester.pumpAndSettle();

      // Place an order
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Your Name *'), 'Bob Dylan');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile Phone Number *'), '09181234567');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Place Order'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      if (find.text('Track Live Status').evaluate().isNotEmpty) {
        await tester.tap(find.text('Track Live Status'));
        await tester.pump(const Duration(milliseconds: 400));
      }

      // We are in tracker view
      expect(find.text('LIVE TRACKER'), findsOneWidget);

      final incoming = await service.fetchIncomingOrders(storeId);
      expect(incoming.length, 1);
      final orderId = incoming.first.id;

      // Simulate order becoming ready and customer completing order
      await service.updateOrderStatus(storeId: storeId, orderId: orderId, newStatus: OrderStatus.ready);
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 400));

      // VERIFICATION: Customer has NO Complete Order button in modal or tracker
      expect(find.byKey(const ValueKey('ready_modal_complete_order_btn')), findsNothing);
      expect(find.byKey(const ValueKey('tracker_complete_order_btn')), findsNothing);

      // If ready modal shows up, dismiss it using "Got it, Thanks!"
      if (find.byKey(const ValueKey('ready_modal_got_it_btn')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('ready_modal_got_it_btn')));
        await tester.pump(const Duration(milliseconds: 400));
      }

      // Cashier completes the order in POS
      await service.updateOrderStatus(storeId: storeId, orderId: orderId, newStatus: OrderStatus.completed);
      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 400));

      // Tracker shows Order Completed
      expect(find.text('Order Completed'), findsAtLeastNWidgets(1));

      // If notification modal shows up upon completion, dismiss it using "Got it, Thanks!"
      if (find.byKey(const ValueKey('ready_modal_got_it_btn')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey('ready_modal_got_it_btn')));
        await tester.pump(const Duration(milliseconds: 400));
      }

      // Tap Back to Menu / Order Again
      await tester.tap(find.text('Back to Menu / Order Again'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // VERIFICATION 1: Track order banner is NOT displayed on menu for completed order
      expect(find.byKey(const ValueKey('recent_order_banner')), findsNothing);

      // VERIFICATION 2: Order is still preserved in customer local cache for history
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('customer_recent_orders_$storeId');
      expect(cachedStr, isNotNull);
      final cachedList = jsonDecode(cachedStr!) as List<dynamic>;
      expect(cachedList.length, 1);
      expect(cachedList.first['status'], equals(OrderStatus.completed.name));

      // VERIFICATION 3: Customer can view history from header bag button
      await tester.tap(find.byKey(const ValueKey('header_order_tracker_btn')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('recent_orders_dialog')), findsOneWidget);
      expect(find.text('View Receipt'), findsOneWidget);
      expect(find.text('Track Live'), findsNothing);

      // Tapping View Receipt opens the order summary
      await tester.tap(find.text('View Receipt'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Order Completed'), findsAtLeastNWidgets(1));

      // Allow any notification/snack bar timers to complete
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('when customer reopens app with completed orders in cache, does not auto-track completed order', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const storeId = 'store_reopen_test';
      final completedOrder = Order(
        id: 'ord_completed_999',
        orderNumber: 'ONL-999',
        items: [
          OrderItem(
            id: 'ord_item_1',
            menuItem: MenuItem(
              id: 'm1',
              name: 'Matcha Latte',
              description: 'Matcha green tea',
              icon: '🍵',
              price: 150.0,
              category: ItemCategory.coffee,
            ),
            quantity: 1,
          ),
        ],
        subtotal: 150.0,
        taxAmount: 0.0,
        taxRate: 0.0,
        discountAmount: 0.0,
        totalAmount: 150.0,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 150.0,
        status: OrderStatus.completed,
        orderType: OrderType.takeaway,
        createdAt: DateTime.now(),
        customerName: 'Cathy',
        cashierName: 'Staff',
      );

      // Pre-seed completed order in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'customer_recent_orders_$storeId',
        jsonEncode([completedOrder.toJson()]),
      );

      final service = OnlineOrderService();
      await service.publishStoreCatalog(
        profile: OnlineStoreProfile(storeId: storeId, ownerEmail: 'test@mail.com', storeName: 'Preloaded Cafe'),
        menuItems: [completedOrder.items.first.menuItem],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerOnlineOrderScreen(storeId: storeId),
        ),
      );
      await tester.pumpAndSettle();

      // VERIFICATION: Recent order banner is NOT shown
      expect(find.byKey(const ValueKey('recent_order_banner')), findsNothing);

      // VERIFICATION: Cache is intact and history dialog shows completed order
      await tester.tap(find.byKey(const ValueKey('header_order_tracker_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recent_orders_dialog')), findsOneWidget);
      expect(find.text('ONL-999'), findsOneWidget);
      expect(find.text('View Receipt'), findsOneWidget);
    });
  });
}
