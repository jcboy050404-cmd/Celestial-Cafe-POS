import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/auth_service.dart';
import 'package:celestial_pos/services/online_order_service.dart';
import 'package:celestial_pos/screens/online_orders_screen.dart';

Order _createSampleOrder({
  required String id,
  required String orderNumber,
  required OrderStatus status,
  required String customerName,
  OrderType orderType = OrderType.takeaway,
}) {
  return Order(
    id: id,
    orderNumber: orderNumber,
    items: [],
    subtotal: 100.0,
    taxAmount: 12.0,
    taxRate: 0.12,
    discountAmount: 0.0,
    totalAmount: 112.0,
    paymentMethod: PaymentMethod.cash,
    amountTendered: 112.0,
    status: status,
    orderType: orderType,
    createdAt: DateTime.now(),
    customerName: customerName,
    cashierName: 'Online Customer',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnlineOrderService deleteOnlineOrder', () {
    test('removes order from mock cache', () async {
      final service = OnlineOrderService();
      service.mockModeOverride = true;
      const storeId = 'test_owner_cafe';

      final sampleOrder = _createSampleOrder(
        id: 'online_order_101',
        orderNumber: 'ONL-101',
        status: OrderStatus.completed,
        customerName: 'Juan Dela Cruz',
      );

      await service.submitCustomerOrder(storeId: storeId, order: sampleOrder);
      var fetched = await service.fetchIncomingOrders(storeId);
      expect(fetched.any((o) => o.id == 'online_order_101'), isTrue);

      final deleted = await service.deleteOnlineOrder(storeId: storeId, orderId: 'online_order_101');
      expect(deleted, isTrue);

      fetched = await service.fetchIncomingOrders(storeId);
      expect(fetched.any((o) => o.id == 'online_order_101'), isFalse);
    });
  });

  group('PosProvider deleteOnlineOrder role enforcement', () {
    test('cashier cannot delete orders or clear completed orders', () async {
      final pos = PosProvider();
      final cashierUser = AppUser(
        uid: 'cashier_1',
        email: 'counter@cafe.com',
        displayName: 'Cashier Staff',
        role: UserRole.cashier,
        ownerEmail: 'owner@cafe.com',
        trialStartDate: DateTime.now(),
      );
      pos.updateCurrentUser(cashierUser);

      final completedOrder = _createSampleOrder(
        id: 'online_del_202',
        orderNumber: 'ONL-202',
        status: OrderStatus.completed,
        customerName: 'Maria Clara',
      );

      pos.addIncomingOnlineOrder(completedOrder);
      expect(pos.incomingOnlineOrders.any((o) => o.id == 'online_del_202'), isTrue);

      // Cashier attempt to delete should fail and be blocked
      final success = await pos.deleteOnlineOrder('online_del_202');
      expect(success, isFalse);
      expect(pos.incomingOnlineOrders.any((o) => o.id == 'online_del_202'), isTrue);

      final clearedCount = await pos.clearCompletedOnlineOrders();
      expect(clearedCount, equals(0));
      expect(pos.incomingOnlineOrders.any((o) => o.id == 'online_del_202'), isTrue);

      // deleteOrderCompletely should also be blocked for cashier
      pos.deleteOrderCompletely('online_del_202');
      expect(pos.incomingOnlineOrders.any((o) => o.id == 'online_del_202'), isTrue);
    });

    test('owner can delete orders and clear completed orders', () async {
      final pos = PosProvider();
      final ownerUser = AppUser(
        uid: 'owner_1',
        email: 'owner@cafe.com',
        displayName: 'Owner Boss',
        role: UserRole.owner,
        trialStartDate: DateTime.now(),
      );
      pos.updateCurrentUser(ownerUser);

      final completedOrder = _createSampleOrder(
        id: 'online_del_203',
        orderNumber: 'ONL-203',
        status: OrderStatus.completed,
        customerName: 'Simoun',
      );

      pos.addIncomingOnlineOrder(completedOrder);
      expect(pos.incomingOnlineOrders.any((o) => o.id == 'online_del_203'), isTrue);

      final success = await pos.deleteOnlineOrder('online_del_203');
      expect(success, isTrue);
      expect(pos.incomingOnlineOrders.any((o) => o.id == 'online_del_203'), isFalse);
    });
  });

  group('OnlineOrdersScreen Widget Tests: Cashier vs Owner Permissions', () {
    testWidgets('Cashier CANNOT see Delete button or Clear All Completed button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cashierUser = AppUser(
        uid: 'cashier_99',
        email: 'cashier@cafe.com',
        displayName: 'Cashier John',
        role: UserRole.cashier,
        ownerEmail: 'owner@cafe.com',
        trialStartDate: DateTime.now(),
      );
      final auth = AuthService(initialUser: cashierUser);
      final pos = PosProvider();
      pos.updateCurrentUser(cashierUser);

      final completedOrder = _createSampleOrder(
        id: 'online_ui_401',
        orderNumber: 'ONL-401',
        status: OrderStatus.completed,
        customerName: 'Crisostomo Ibarra',
      );
      pos.addIncomingOnlineOrder(completedOrder);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: pos),
            ChangeNotifierProvider<AuthService>.value(value: auth),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OnlineOrdersScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find order card
      expect(find.text('ONL-401'), findsOneWidget);

      // Verify Delete button is NOT visible for cashier
      expect(find.text('Delete'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

      // Tap the 'Completed' status filter chip
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // Verify Clear All Completed button is NOT visible for cashier
      expect(find.textContaining('Clear All Completed'), findsNothing);
      expect(find.byIcon(Icons.delete_sweep_rounded), findsNothing);
    });

    testWidgets('Owner CAN see Delete button and delete completed online order', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ownerUser = AppUser(
        uid: 'owner_99',
        email: 'owner@cafe.com',
        displayName: 'Owner Boss',
        role: UserRole.owner,
        trialStartDate: DateTime.now(),
      );
      final auth = AuthService(initialUser: ownerUser);
      final pos = PosProvider();
      pos.updateCurrentUser(ownerUser);

      final completedOrder = _createSampleOrder(
        id: 'online_ui_402',
        orderNumber: 'ONL-402',
        status: OrderStatus.completed,
        customerName: 'Maria Clara',
      );
      pos.addIncomingOnlineOrder(completedOrder);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: pos),
            ChangeNotifierProvider<AuthService>.value(value: auth),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OnlineOrdersScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find order card
      expect(find.text('ONL-402'), findsOneWidget);

      // Verify Delete button IS visible for owner
      expect(find.text('Delete'), findsOneWidget);

      // Tap Delete button to open confirmation dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog title and prompt
      expect(find.text('Delete Order ONL-402?'), findsOneWidget);
      expect(find.text('Delete Permanently'), findsOneWidget);

      // Tap Delete Permanently in the dialog
      await tester.tap(find.text('Delete Permanently'));
      await tester.pumpAndSettle();

      // Verify the order has been removed from the list
      expect(find.text('ONL-402'), findsNothing);
      expect(pos.incomingOnlineOrders.any((o) => o.id == 'online_ui_402'), isFalse);
    });

    testWidgets('Owner CAN see Clear All Completed button and clear all completed orders', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ownerUser = AppUser(
        uid: 'owner_99',
        email: 'owner@cafe.com',
        displayName: 'Owner Boss',
        role: UserRole.owner,
        trialStartDate: DateTime.now(),
      );
      final auth = AuthService(initialUser: ownerUser);
      final pos = PosProvider();
      pos.updateCurrentUser(ownerUser);

      final completedOrder = _createSampleOrder(
        id: 'online_bulk_501',
        orderNumber: 'ONL-501',
        status: OrderStatus.completed,
        customerName: 'Elias',
      );
      pos.addIncomingOnlineOrder(completedOrder);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: pos),
            ChangeNotifierProvider<AuthService>.value(value: auth),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OnlineOrdersScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the 'Completed' status filter chip
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // Verify Clear All Completed button appears for owner
      expect(find.text('Clear All Completed (1)'), findsOneWidget);

      // Tap Clear All Completed button
      await tester.tap(find.text('Clear All Completed (1)'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Clear Completed Orders?'), findsOneWidget);
      expect(find.text('Delete All (1)'), findsOneWidget);

      // Confirm bulk deletion
      await tester.tap(find.text('Delete All (1)'));
      await tester.pumpAndSettle();

      // Verify order is removed
      expect(find.text('ONL-501'), findsNothing);
      expect(pos.incomingOnlineOrders.isEmpty, isTrue);
    });
  });
}
