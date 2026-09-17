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
import 'package:celestial_pos/widgets/online_order_confirm_dialog.dart';

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
      expect(generalUrl, 'https://jc-pos-system.web.app/#/order?store=owner1_at_celestialcafe_com');

      final tableUrl = OnlineOrderService.getOrderingUrl(
        storeId: 'owner1_at_celestialcafe_com',
        tableNumber: 'Table 04',
      );
      expect(tableUrl, 'https://jc-pos-system.web.app/#/order?store=owner1_at_celestialcafe_com&table=Table%2004');
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

  group('Cashier Online Order Confirmation Tests', () {
    testWidgets('Cashier can review and confirm online order with confirmation dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = AuthService(
        initialUser: AppUser(
          uid: 'cashier_uid',
          email: 'cashier@cafe.com',
          displayName: 'Maria (Cashier)',
          role: UserRole.cashier,
          ownerEmail: 'owner@cafe.com',
          trialStartDate: DateTime.now(),
        ),
      );

      final posProvider = PosProvider();
      await posProvider.loadForUser('owner@cafe.com');

      final testOrder = Order(
        id: 'online_order_confirm_1',
        orderNumber: 'ONL-99',
        orderType: OrderType.dineIn,
        tableNumber: 'Table 12',
        customerName: 'Alex Cruz',
        customerPhone: '09171234567',
        items: [
          OrderItem(
            id: 'test_item_1',
            menuItem: MenuItem(
              id: 'm1',
              name: 'Iced Americano',
              description: 'Bold espresso over ice',
              icon: '☕',
              price: 120.0,
              category: ItemCategory.coffee,
            ),
            quantity: 2,
          ),
        ],
        subtotal: 240.0,
        taxAmount: 0.0,
        taxRate: 0.0,
        totalAmount: 240.0,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 240.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        cashierName: 'Online Web Order',
        orderNotes: 'Less ice please',
      );

      // Submit online order
      await OnlineOrderService().submitCustomerOrder(
        storeId: 'owner_at_cafe_com',
        order: testOrder,
      );
      await posProvider.pollOnlineOrders();

      expect(posProvider.incomingOnlineOrders.length, 1);
      expect(posProvider.incomingOnlineOrders.first.status, OrderStatus.pending);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OnlineOrderConfirmDialog(order: testOrder),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify customer details and notes are shown in dialog
      expect(find.text('ONL-99'), findsOneWidget);
      expect(find.text('Alex Cruz'), findsOneWidget);
      expect(find.text('📞 09171234567'), findsOneWidget);
      expect(find.text('Dine-In Location: Table 12'), findsOneWidget);
      expect(find.text('Note to Kitchen: "Less ice please"'), findsOneWidget);
      expect(find.text('₱240.00'), findsNWidgets(2)); // Item line and Total

      // Cashier clicks Confirm & Send to Kitchen
      await tester.tap(find.text('Confirm & Send to Kitchen'));
      await tester.pumpAndSettle();

      // Verify order is now preparing and assigned to Maria (Cashier)
      expect(testOrder.status, OrderStatus.preparing);
      expect(testOrder.cashierName, 'Maria (Cashier)');

      posProvider.dispose();
    });
  });

  group('Custom Online Order Link & Slug Resolution', () {
    test('slugify and validateCustomSlug correctly format and validate custom links', () {
      expect(OnlineOrderService.slugify("Neil's Special Coffee & Cafe"), 'neils-special-coffee-cafe');
      expect(OnlineOrderService.slugify("  Celestial--Cafe 2026! "), 'celestial-cafe-2026');
      expect(OnlineOrderService.slugify("My_Cafe_Branch"), 'my-cafe-branch');

      // Validation
      expect(OnlineOrderService.validateCustomSlug('hi'), isNotNull); // Too short
      expect(OnlineOrderService.validateCustomSlug('order'), isNotNull); // Reserved
      expect(OnlineOrderService.validateCustomSlug('my-cool-cafe'), isNull); // Valid
    });

    test('getOrderingUrl uses customSlug when provided', () {
      final customUrl = OnlineOrderService.getOrderingUrl(
        storeId: 'owner_at_cafe_com',
        customSlug: 'my-custom-cafe',
        tableNumber: 'Table 1',
      );
      expect(customUrl, 'https://jc-pos-system.web.app/#/order?store=my-custom-cafe&table=Table%201');
    });

    test('Owner can set custom link, resolve slug, and customers can order via custom slug', () async {
      final service = OnlineOrderService();
      final ownerEmail = 'customowner@cafe.com';
      final storeId = OnlineOrderService.getStoreId(ownerEmail);
      final customSlug = 'celestial-downtown';

      // 1. Check availability
      final avail = await service.checkSlugAvailability(slug: customSlug, ownerEmail: ownerEmail);
      expect(avail.available, isTrue);

      // 2. Publish catalog with customSlug
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: ownerEmail,
        storeName: 'Downtown Branch',
        customSlug: customSlug,
      );
      final menu = [
        MenuItem(
          id: 'custom_m1',
          name: 'Downtown Cold Brew',
          description: 'Steeped for 18 hours',
          icon: '☕',
          price: 130.0,
          category: ItemCategory.coffee,
        ),
      ];
      await service.publishStoreCatalog(profile: profile, menuItems: menu);

      // 3. Resolve slug to actual storeId
      final resolved = await service.resolveStoreId(customSlug);
      expect(resolved, storeId);

      // 4. Fetch catalog using customSlug
      final fetched = await service.fetchStoreCatalog(customSlug);
      expect(fetched, isNotNull);
      final fetchedProfile = fetched!['profile'] as OnlineStoreProfile;
      expect(fetchedProfile.storeName, 'Downtown Branch');
      expect(fetchedProfile.customSlug, customSlug);

      // 5. Submit customer order using customSlug
      final testOrder = Order(
        id: 'order_custom_slug_1',
        orderNumber: '#ON-SLUG-1',
        orderType: OrderType.takeaway,
        customerName: 'Slug Customer',
        customerPhone: '09123456789',
        items: [OrderItem(id: 'ci1', menuItem: menu.first, quantity: 1)],
        subtotal: 130.0,
        taxAmount: 0.0,
        taxRate: 0.0,
        totalAmount: 130.0,
        paymentMethod: PaymentMethod.cash,
        amountTendered: 130.0,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        cashierName: 'Online Web Order',
      );
      final submitted = await service.submitCustomerOrder(storeId: customSlug, order: testOrder);
      expect(submitted, isTrue);

      // 6. POS fetching by real storeId receives the order placed via custom slug
      final orders = await service.fetchIncomingOrders(storeId);
      expect(orders.any((o) => o.id == 'order_custom_slug_1'), isTrue);
    });

    testWidgets('Owner can input custom link in dialog and save it', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = AuthService(
        initialUser: AppUser(
          uid: 'owner_uid_2',
          email: 'customowner2@cafe.com',
          displayName: 'Cafe Boss',
          role: UserRole.owner,
          trialStartDate: DateTime.now(),
        ),
      );

      final posProvider = PosProvider();
      await posProvider.loadForUser('customowner2@cafe.com');

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

      // Verify custom link section is rendered
      expect(find.text('Custom Ordering Link'), findsOneWidget);
      expect(find.text('Save Link'), findsOneWidget);

      // Input custom link name
      final slugField = find.widgetWithText(TextField, 'your-custom-link');
      expect(slugField, findsOneWidget);
      await tester.enterText(slugField, 'my-super-cafe');
      await tester.pumpAndSettle();

      // Tap Save Link
      await tester.tap(find.text('Save Link'));
      await tester.pumpAndSettle();

      // Verify custom link is now active in provider and shown in dialog
      expect(posProvider.customSlug, 'my-super-cafe');
      expect(find.text('Custom Active'), findsOneWidget);

      posProvider.dispose();
    });
  });
}

