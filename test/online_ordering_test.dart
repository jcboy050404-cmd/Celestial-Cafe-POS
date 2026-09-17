import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/screens/customer_online_order_screen.dart';
import 'package:celestial_pos/services/auth_service.dart';
import 'package:celestial_pos/services/online_order_service.dart';
import 'package:celestial_pos/widgets/online_ordering_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OnlineOrderService & URL Generation', () {
    test('getStoreId generates deterministic URL-safe store keys', () {
      expect(
        OnlineOrderService.getStoreId('owner1@celestialcafe.com'),
        'owner1_at_celestialcafe_com',
      );
      expect(
        OnlineOrderService.getStoreId('cafe.branch-2@gmail.com'),
        'cafe_branch_2_at_gmail_com',
      );
    });

    test('getOrderingUrl builds proper web links with optional table number', () {
      final generalUrl = OnlineOrderService.getOrderingUrl(
        storeId: 'owner1_at_celestialcafe_com',
      );
      expect(generalUrl, 'https://celestialcafe.web.app/#/order?store=owner1_at_celestialcafe_com');

      final tableUrl = OnlineOrderService.getOrderingUrl(
        storeId: 'owner1_at_celestialcafe_com',
        tableNumber: 'Table 04',
      );
      expect(tableUrl, 'https://celestialcafe.web.app/#/order?store=owner1_at_celestialcafe_com&table=Table%2004');
    });
  });

  group('Multi-Owner Online Ordering Isolation', () {
    test('Owner A and Owner B have strictly separate catalogs and incoming orders', () async {
      final service = OnlineOrderService();

      final ownerAStoreId = OnlineOrderService.getStoreId('ownerA@cafe.com');
      final ownerBStoreId = OnlineOrderService.getStoreId('ownerB@cafe.com');

      expect(ownerAStoreId, isNot(equals(ownerBStoreId)));

      // 1. Owner A publishes menu with 2 items
      final List<MenuItem> menuA = [
        MenuItem(
          id: 'item_a1',
          name: 'Owner A Signature Brew',
          description: 'Dark roasted blend',
          icon: '☕',
          price: 150.0,
          category: ItemCategory.coffee,
        ),
      ];
      final profileA = OnlineStoreProfile(
        storeId: ownerAStoreId,
        ownerEmail: 'ownerA@cafe.com',
        storeName: "Owner A's Cozy Cafe",
      );
      await service.publishStoreCatalog(profile: profileA, menuItems: menuA);

      // 2. Owner B publishes menu with different item
      final List<MenuItem> menuB = [
        MenuItem(
          id: 'item_b1',
          name: 'Owner B Golden Milk',
          description: 'Spiced golden milk',
          icon: '🧋',
          price: 180.0,
          category: ItemCategory.milktea,
        ),
      ];
      final profileB = OnlineStoreProfile(
        storeId: ownerBStoreId,
        ownerEmail: 'ownerB@cafe.com',
        storeName: "Owner B's Golden Cafe",
      );
      await service.publishStoreCatalog(profile: profileB, menuItems: menuB);

      // 3. Customer fetching Owner A's catalog receives only Owner A's items
      final catalogA = await service.fetchStoreCatalog(ownerAStoreId);
      expect(catalogA, isNotNull);
      final fetchedMenuA = catalogA!['menu'] as List<MenuItem>;
      expect(fetchedMenuA.any((m) => m.name == 'Owner A Signature Brew'), isTrue);
      expect(fetchedMenuA.any((m) => m.name == 'Owner B Golden Milk'), isFalse);

      // 4. Customer fetching Owner B's catalog receives only Owner B's items
      final catalogB = await service.fetchStoreCatalog(ownerBStoreId);
      expect(catalogB, isNotNull);
      final fetchedMenuB = catalogB!['menu'] as List<MenuItem>;
      expect(fetchedMenuB.any((m) => m.name == 'Owner B Golden Milk'), isTrue);
      expect(fetchedMenuB.any((m) => m.name == 'Owner A Signature Brew'), isFalse);

      // 5. Customer places order on Owner A's store
      final orderForA = Order(
        id: 'online_order_101',
        orderNumber: '#ON-101',
        orderType: OrderType.takeaway,
        customerName: 'Customer John',
        customerPhone: '09123456789',
        items: [
          OrderItem(id: 'i1', menuItem: menuA.first, quantity: 2),
        ],
        subtotal: 300.0,
        taxAmount: 0.0,
        taxRate: 0.0,
        totalAmount: 300.0,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 300.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        cashierName: 'Online Web Order',
      );
      await service.submitCustomerOrder(storeId: ownerAStoreId, order: orderForA);

      // 6. Verify Owner A's POS sees the order, but Owner B sees 0 orders
      final ordersA = await service.fetchIncomingOrders(ownerAStoreId);
      final ordersB = await service.fetchIncomingOrders(ownerBStoreId);

      expect(ordersA.length, 1);
      expect(ordersA.first.id, 'online_order_101');
      expect(ordersB.isEmpty, isTrue); // STRICT SEPARATION
    });
  });

  group('CustomerOnlineOrderScreen Widget Tests', () {
    testWidgets('Renders store menu, categories, and allows adding to cart', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'test_owner_at_cafe_com';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'test_owner@cafe.com',
        storeName: 'Celestial Coffee Roasters',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'test_m1',
          name: 'Iced Spanish Latte',
          description: 'Espresso with condensed milk and cinnamon',
          icon: '☕',
          price: 140.0,
          category: ItemCategory.coffee,
        ),
      ];
      await service.publishStoreCatalog(profile: profile, menuItems: menu);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOnlineOrderScreen(storeId: storeId),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Store Name and Menu Item render
      expect(find.text('Celestial Coffee Roasters'), findsOneWidget);
      expect(find.text('Iced Spanish Latte'), findsOneWidget);
      expect(find.text('₱140.00'), findsOneWidget);

      // Tap Add to Cart
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Verify bottom cart bar appears
      expect(find.text('1 item in cart'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
    });
  });

  group('OnlineOrderingDialog Widget Tests', () {
    testWidgets('Owner dialog renders QR code, copy link, and store controls', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = AuthService(
        initialUser: AppUser(
          uid: 'owner_uid',
          email: 'owner@celestialcafe.com',
          displayName: 'Store Owner',
          role: UserRole.owner,
          trialStartDate: DateTime.now(),
        ),
      );

      final posProvider = PosProvider();
      await posProvider.loadForUser('owner@celestialcafe.com');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OnlineOrderingDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Dialog header and tabs
      expect(find.text('Customer Online Ordering'), findsOneWidget);
      expect(find.text('Ordering Link & QR'), findsOneWidget);
      expect(find.text('Store Controls'), findsOneWidget);
      expect(find.text('Copy Link'), findsOneWidget);
      expect(find.text('Share Link'), findsOneWidget);

      // Switch to Store Controls tab
      await tester.tap(find.text('Store Controls'));
      await tester.pumpAndSettle();

      // Verify Store Controls content
      expect(find.text('ONLINE ORDERING IS ACTIVE'), findsOneWidget);
      expect(find.text('Dine-In (Table QR Ordering)'), findsOneWidget);
      expect(find.text('Takeaway / Pickup'), findsOneWidget);
      expect(find.text('Delivery'), findsOneWidget);

      posProvider.dispose();
    });
  });
}
