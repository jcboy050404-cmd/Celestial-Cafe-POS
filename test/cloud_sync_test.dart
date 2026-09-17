import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/cloud_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Monthly Sales & Menu Cloud Sync Tests', () {
    test('PosProvider tracks currentUserEmail across load and clear session', () async {
      final pos = PosProvider();
      expect(pos.currentUserEmail, isNull);

      await pos.loadForUser('manager@celestialcafe.com');
      expect(pos.currentUserEmail, equals('manager@celestialcafe.com'));

      await pos.clearUserSession();
      expect(pos.currentUserEmail, isNull);
    });

    test('PosProvider completeCheckout records order and invokes background sync safely', () async {
      final pos = PosProvider();
      await pos.loadForUser('cashier@celestialcafe.com');

      final sampleItem = pos.menuItems.first;
      pos.addToCart(sampleItem);
      expect(pos.cart.length, equals(1));

      final order = pos.completeCheckout(
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500.0,
      );

      expect(order.status, equals(OrderStatus.completed));
      expect(pos.orders.first.id, equals(order.id));
      expect(pos.cart, isEmpty);

      // Verify year-month format
      final yearMonth =
          '${order.createdAt.year.toString().padLeft(4, '0')}-${order.createdAt.month.toString().padLeft(2, '0')}';
      expect(yearMonth.length, equals(7));
      expect(yearMonth, contains('-'));
    });

    test('CloudBackupService handles empty email gracefully without throwing', () async {
      final cloud = CloudBackupService();
      final order = Order(
        id: 'ord_test',
        orderNumber: '#1',
        orderType: OrderType.dineIn,
        customerName: 'Test Customer',
        items: [],
        subtotal: 100,
        taxAmount: 0,
        taxRate: 0,
        totalAmount: 100,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 100,
        status: OrderStatus.completed,
        createdAt: DateTime.now(),
        cashierName: 'POS',
      );

      final saleRes = await cloud.recordMonthlySaleTransaction(
        userEmail: '',
        order: order,
      );
      expect(saleRes, isFalse);

      final menuRes = await cloud.syncMenuToCloud(
        userEmail: '',
        menuItems: [],
        customCategories: [],
      );
      expect(menuRes, isFalse);

      final fetchMenu = await cloud.fetchMenuFromCloud('');
      expect(fetchMenu, isNull);

      final fetchSales = await cloud.fetchMonthlySalesHistory(
        userEmail: '',
        yearMonth: '2026-09',
      );
      expect(fetchSales, isEmpty);
    });

    test('PosProvider removeAllCategories clears all categories and restoreSystemCategories restores them', () async {
      final pos = PosProvider();
      await pos.loadForUser('test@celestialcafe.com');

      // Initially has system categories (10 tabs: All + 9 system)
      expect(pos.hideSystemCategories, isFalse);
      expect(pos.allCategoryTabs.length, equals(10));

      // Add a custom category
      pos.addCustomCategory(name: 'Seasonal Specials', icon: '🍁');
      expect(pos.customCategories.length, equals(1));
      expect(pos.allCategoryTabs.length, equals(11));

      // Remove all categories
      await pos.removeAllCategories();
      expect(pos.hideSystemCategories, isTrue);
      expect(pos.customCategories, isEmpty);
      // Only 'All Items' tab remains
      expect(pos.allCategoryTabs.length, equals(1));
      expect(pos.allCategoryTabs.first.id, equals('all'));
      expect(pos.selectedCategoryId, equals('all'));

      // Restore system categories
      await pos.restoreSystemCategories();
      expect(pos.hideSystemCategories, isFalse);
      expect(pos.allCategoryTabs.length, equals(10));
    });

    test('CloudBackupService offline pending sales queue enqueues, deduplicates, and dequeues', () async {
      final cloud = CloudBackupService();
      const testEmail = 'offline_tester@celestialcafe.com';

      expect(await cloud.getPendingSalesCount(testEmail), equals(0));

      final sampleOrder1 = Order(
        id: 'ord_offline_1',
        orderNumber: '#101',
        orderType: OrderType.dineIn,
        customerName: 'Alice',
        items: [],
        subtotal: 250,
        taxAmount: 0,
        taxRate: 0,
        totalAmount: 250,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 300,
        status: OrderStatus.completed,
        createdAt: DateTime.now(),
        cashierName: 'Station 1',
      );

      final sampleOrder2 = Order(
        id: 'ord_offline_2',
        orderNumber: '#102',
        orderType: OrderType.takeaway,
        customerName: 'Bob',
        items: [],
        subtotal: 150,
        taxAmount: 0,
        taxRate: 0,
        totalAmount: 150,
        paymentMethod: PaymentMethod.mobilePay,
        amountTendered: 150,
        status: OrderStatus.completed,
        createdAt: DateTime.now(),
        cashierName: 'Station 1',
      );

      // Enqueue order 1
      await cloud.enqueuePendingOrder(userEmail: testEmail, order: sampleOrder1);
      expect(await cloud.getPendingSalesCount(testEmail), equals(1));

      // Attempt duplicate enqueue (should be ignored)
      await cloud.enqueuePendingOrder(userEmail: testEmail, order: sampleOrder1);
      expect(await cloud.getPendingSalesCount(testEmail), equals(1));

      // Enqueue order 2
      await cloud.enqueuePendingOrder(userEmail: testEmail, order: sampleOrder2);
      expect(await cloud.getPendingSalesCount(testEmail), equals(2));

      final queued = await cloud.getPendingOrders(testEmail);
      expect(queued.length, equals(2));
      expect(queued[0].id, equals('ord_offline_1'));
      expect(queued[1].id, equals('ord_offline_2'));

      // Dequeue order 1
      await cloud.dequeuePendingOrder(userEmail: testEmail, orderId: 'ord_offline_1');
      expect(await cloud.getPendingSalesCount(testEmail), equals(1));

      final remaining = await cloud.getPendingOrders(testEmail);
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('ord_offline_2'));

      // Clean up
      await cloud.dequeuePendingOrder(userEmail: testEmail, orderId: 'ord_offline_2');
      expect(await cloud.getPendingSalesCount(testEmail), equals(0));
    });

    test('PosProvider tracks pendingSyncCount and refreshes correctly', () async {
      final pos = PosProvider();
      const userEmail = 'pos_queue@celestialcafe.com';
      await pos.loadForUser(userEmail);

      expect(pos.pendingSyncCount, equals(0));

      // Manually add to pending queue
      final cloud = CloudBackupService();
      final offlineOrder = Order(
        id: 'ord_offline_pos',
        orderNumber: '#200',
        orderType: OrderType.dineIn,
        customerName: 'Charlie',
        items: [],
        subtotal: 400,
        taxAmount: 0,
        taxRate: 0,
        totalAmount: 400,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 500,
        status: OrderStatus.completed,
        createdAt: DateTime.now(),
        cashierName: 'POS',
      );
      await cloud.enqueuePendingOrder(userEmail: userEmail, order: offlineOrder);

      await pos.refreshPendingSyncCount();
      expect(pos.pendingSyncCount, equals(1));

      // Clear session resets pending sync count
      await pos.clearUserSession();
      expect(pos.pendingSyncCount, equals(0));
      expect(pos.currentUserEmail, isNull);
    });
  });
}
