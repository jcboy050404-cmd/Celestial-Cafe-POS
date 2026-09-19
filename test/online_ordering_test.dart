import 'dart:convert';
import 'dart:typed_data';
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
import 'package:celestial_pos/widgets/header_bar.dart';

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

      // Verify Store Name, Signature Craft banner, and Menu Item render without .00
      expect(find.text('Celestial Coffee Roasters'), findsOneWidget);
      expect(find.textContaining('SIGNATURE CRAFT'), findsOneWidget);
      expect(find.text('Iced Spanish Latte'), findsWidgets);
      expect(find.text('₱140'), findsWidgets);

      // Tap Add to Cart
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      // Verify bottom cart bar appears
      expect(find.text('1 item in cart'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
    });

    testWidgets('CustomerOnlineOrderScreen renders desktop layout cleanly on PC widescreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'desktop_pc_store';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'desktop@cafe.com',
        storeName: 'Celestial Coffee Roasters',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'test_pc_1',
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

      // Verify desktop header elements
      expect(find.text('Celestial Coffee Roasters'), findsOneWidget);
      expect(find.text('OPEN'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify menu item and action
      expect(find.text('Iced Spanish Latte'), findsWidgets);
      expect(find.text('Add'), findsOneWidget);
    });

    testWidgets('CustomerOnlineOrderScreen bottom cart bar stays anchored to bottom and preserves menu catalog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'cart_bottom_anchor_store';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'cart@cafe.com',
        storeName: 'Celestial Coffee Roasters',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'test_c_1',
          name: 'Iced Spanish Latte',
          description: 'Espresso with condensed milk',
          icon: '☕',
          price: 90.0,
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

      // Tap Add to Cart
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      // Verify bottom cart bar appears
      final checkoutFinder = find.text('Checkout');
      expect(checkoutFinder, findsOneWidget);

      // Verify checkout button is anchored near bottom (Y > 950 on a 1080px screen)
      final checkoutY = tester.getTopLeft(checkoutFinder).dy;
      expect(checkoutY, greaterThan(950.0));

      // Verify header is still visible at the top
      final headerY = tester.getTopLeft(find.text('Celestial Coffee Roasters')).dy;
      expect(headerY, lessThan(100.0));

      // Verify menu item is still visible
      expect(find.text('Iced Spanish Latte'), findsWidgets);
    });

    testWidgets('CustomerOnlineOrderScreen preserves recent order when returning to menu, allows re-tracking, and saves locally', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'recent_order_test_store';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'recent@cafe.com',
        storeName: 'Celestial Cafe Roasters',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'item_rec_1',
          name: 'Americano',
          description: 'Rich dark espresso',
          icon: '☕',
          price: 90.0,
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

      // 1. Add Americano to cart
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      // 2. Open checkout modal from cart bar
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      // Fill in customer details
      final nameField = find.widgetWithText(TextField, 'Your Name *');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Juan Dela Cruz');

      final phoneField = find.widgetWithText(TextField, 'Mobile Phone Number *');
      expect(phoneField, findsOneWidget);
      await tester.enterText(phoneField, '09171234567');
      await tester.pumpAndSettle();

      // Submit order
      final placeOrderBtn = find.textContaining('Place Order');
      expect(placeOrderBtn, findsOneWidget);
      await tester.tap(placeOrderBtn);
      await tester.pumpAndSettle();

      // 3. User is now on the Live Order Tracker screen!
      expect(find.text('LIVE TRACKER'), findsOneWidget);
      expect(find.text('Handcrafted Coffee & Treats'), findsOneWidget);
      expect(find.text('Back to Menu / Order Again'), findsOneWidget);

      // 4. Tap "Back to Menu / Order Again"
      await tester.tap(find.text('Back to Menu / Order Again'));
      await tester.pumpAndSettle();

      // 5. User is back to Menu catalog, but recent order banner & header bag button are visible!
      expect(find.byKey(const ValueKey('recent_order_banner')), findsOneWidget);
      expect(find.byKey(const ValueKey('header_order_tracker_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('header_bag_active_indicator')), findsOneWidget);
      expect(find.text('Track Order'), findsOneWidget);

      // 6. Tap header bag button to return to Live Order Tracker
      await tester.tap(find.byKey(const ValueKey('header_order_tracker_btn')));
      await tester.pumpAndSettle();

      expect(find.text('LIVE TRACKER'), findsOneWidget);
      expect(find.text('Handcrafted Coffee & Treats'), findsOneWidget);

      // 7. Verify redundant top bar back button is removed, and tap bottom "Back to Menu / Order Again" button
      expect(find.byKey(const ValueKey('tracker_top_back_btn')), findsNothing);
      await tester.tap(find.text('Back to Menu / Order Again'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recent_order_banner')), findsOneWidget);

      // 8. Dismiss recent order banner
      await tester.tap(find.byTooltip('Dismiss order banner'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recent_order_banner')), findsNothing);
      expect(find.byKey(const ValueKey('header_bag_active_indicator')), findsNothing);

      // 9. Tap header bag button when no active order: opens No Active Orders dialog
      await tester.tap(find.byKey(const ValueKey('header_order_tracker_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('no_active_orders_dialog')), findsOneWidget);
      expect(find.text('No Active Orders'), findsOneWidget);
      await tester.tap(find.text('Browse Menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('no_active_orders_dialog')), findsNothing);
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

  group('Owner Store Controls & Closed Order Blocking Tests', () {
    testWidgets('Owner can toggle store status and save custom notice in dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final auth = AuthService(
        initialUser: AppUser(
          uid: 'owner_uid_ctrl',
          email: 'storeboss@cafe.com',
          displayName: 'Store Boss',
          role: UserRole.owner,
          trialStartDate: DateTime.now(),
        ),
      );

      final posProvider = PosProvider();
      await posProvider.loadForUser('storeboss@cafe.com');

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

      // Switch to Store Controls Tab
      await tester.tap(find.text('Store Controls'));
      await tester.pumpAndSettle();

      // Verify controls sections
      expect(find.text('STORE ANNOUNCEMENT & CLOSED MESSAGE'), findsOneWidget);
      expect(find.text('ONLINE ORDERING IS ACTIVE'), findsOneWidget);
      expect(find.text('Save Message'), findsOneWidget);
      expect(find.text('Closed for the day'), findsOneWidget);

      // Tap preset chip "Closed for the day"
      await tester.ensureVisible(find.text('Closed for the day'));
      await tester.tap(find.text('Closed for the day'));
      await tester.pumpAndSettle();

      // Save Message
      await tester.ensureVisible(find.text('Save Message'));
      await tester.tap(find.text('Save Message'));
      await tester.pumpAndSettle();
      expect(posProvider.onlineStoreNotice, 'Closed for the day');

      // Tap Pause Orders
      await tester.ensureVisible(find.text('Pause Orders'));
      await tester.tap(find.text('Pause Orders'));
      await tester.pumpAndSettle();
      expect(posProvider.isOnlineOrderOpen, isFalse);
      expect(find.text('ONLINE ORDERING IS PAUSED'), findsOneWidget);

      posProvider.dispose();
    });

    testWidgets('CustomerOnlineOrderScreen displays closed banner and blocks ordering when store is closed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'closed_cafe_at_gmail_com';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'closed_cafe@gmail.com',
        storeName: 'Celestial Roastery',
        isOpen: false,
        customNotice: 'Closed for private event until 6 PM',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'item_roast_1',
          name: 'Signature Latte',
          description: 'Velvety espresso & microfoam',
          icon: '☕',
          price: 150.0,
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

      // 1. Verify Store Header shows PAUSED badge
      expect(find.text('PAUSED'), findsOneWidget);

      // 2. Verify Closed Store Modal automatically pops up on landing
      expect(find.byKey(const ValueKey('closed_store_modal')), findsOneWidget);
      expect(find.text('ONLINE ORDERING IS PAUSED'), findsWidgets);
      expect(find.text('Closed for private event until 6 PM'), findsWidgets);
      expect(find.text('CLOSED'), findsWidgets);
      expect(find.text('Browse Menu'), findsOneWidget);

      // 3. Dismiss the modal by clicking "Browse Menu"
      await tester.tap(find.text('Browse Menu'));
      await tester.pumpAndSettle();

      // Modal is now dismissed, but banner remains visible
      expect(find.byKey(const ValueKey('closed_store_modal')), findsNothing);
      expect(find.byKey(const ValueKey('store_notice_banner')), findsOneWidget);

      // 4. Verify Best Seller banner and item button shows "Closed"
      expect(find.text('Closed'), findsWidgets);

      // 5. Verify item card displays "STORE CLOSED" overlay
      expect(find.text('STORE CLOSED'), findsWidgets);

      // 6. Tap on the menu item: order is blocked and modal pops up again
      await tester.tap(find.text('Signature Latte').first);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('closed_store_modal')), findsOneWidget);
      expect(find.text('Closed for private event until 6 PM'), findsWidgets);

      // Dismiss modal again
      await tester.tap(find.text('Browse Menu'));
      await tester.pumpAndSettle();

      // 7. Tap on the notice banner directly: re-opens the closed store modal
      await tester.tap(find.byKey(const ValueKey('store_notice_banner')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('closed_store_modal')), findsOneWidget);
    });

    test('PosProvider programmatic methods setOnlineStoreOpen and setCustomNotice work as expected', () async {
      final posProvider = PosProvider();
      await posProvider.loadForUser('admin_owner@cafe.com');

      expect(posProvider.isOnlineOrderOpen, isTrue);

      await posProvider.setOnlineStoreOpen(false);
      expect(posProvider.isOnlineOrderOpen, isFalse);

      await posProvider.setCustomNotice('Back in 15 minutes');
      expect(posProvider.onlineStoreNotice, 'Back in 15 minutes');

      await posProvider.setOnlineStoreOpen(true);
      expect(posProvider.isOnlineOrderOpen, isTrue);

      await posProvider.setCustomNotice('');
      expect(posProvider.onlineStoreNotice, isNull);

      posProvider.dispose();
    });

    testWidgets('HeaderBar displays Online Ordering QR button on mobile viewport and opens dialog', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final posProvider = PosProvider();
      await posProvider.loadForUser('owner@cafe.com');

      final authService = AuthService.instance;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
            ChangeNotifierProvider<AuthService>.value(value: authService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HeaderBar(isScrolled: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify mobile online ordering button is present
      final mobileBtn = find.byKey(const ValueKey('mobile_online_order_btn'));
      expect(mobileBtn, findsOneWidget);

      // Verify tooltip and icon
      expect(find.byIcon(Icons.qr_code_2_rounded), findsWidgets);

      // Tap to open OnlineOrderingDialog
      await tester.tap(mobileBtn);
      await tester.pumpAndSettle();

      // Verify OnlineOrderingDialog opened with QR Code & Link tab
      expect(find.byType(OnlineOrderingDialog), findsOneWidget);
      expect(find.text('Customer Online Ordering'), findsOneWidget);
      expect(find.text('Ordering Link & QR'), findsOneWidget);

      posProvider.dispose();
    });

    testWidgets('HeaderBar displays Online Orders navigation tab on desktop and switches nav index to 5', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final posProvider = PosProvider();
      await posProvider.loadForUser('owner@cafe.com');

      // Create a mock incoming online order to verify badge count
      posProvider.addIncomingOnlineOrder(
        Order(
          id: 'online_test_101',
          orderNumber: '#ON-101',
          items: [],
          subtotal: 100.0,
          taxAmount: 12.0,
          taxRate: 0.12,
          discountAmount: 0.0,
          totalAmount: 112.0,
          paymentMethod: PaymentMethod.cash,
          amountTendered: 112.0,
          status: OrderStatus.pending,
          orderType: OrderType.takeaway,
          createdAt: DateTime.now(),
          customerName: 'Online Jane',
          cashierName: 'Online Customer',
        ),
      );

      final authService = AuthService.instance;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
            ChangeNotifierProvider<AuthService>.value(value: authService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HeaderBar(isScrolled: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Online Orders tab is rendered on header
      final onlineOrdersTab = find.text('Online Orders');
      expect(onlineOrdersTab, findsOneWidget);

      // Verify badge count of 1 is visible on Online Orders tab
      expect(find.text('1'), findsOneWidget);

      // Tap Online Orders tab
      await tester.tap(onlineOrdersTab);
      await tester.pumpAndSettle();

      // Verify posProvider navigation index changed to 5
      expect(posProvider.currentNavIndex, equals(5));

      posProvider.dispose();
    });

    testWidgets('Cashier can see Online Orders nav tab but cannot access QR or store controls; Owner can access QR', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Cashier Role User
      final cashierUser = AppUser(
        uid: 'cashier_user_42',
        email: 'cashier@cafe.com',
        displayName: 'Store Cashier',
        tier: SubscriptionTier.trial,
        trialStartDate: DateTime.now(),
        role: UserRole.cashier,
        ownerEmail: 'owner@cafe.com',
      );
      final cashierAuthService = AuthService(initialUser: cashierUser);
      final cashierPosProvider = PosProvider();
      await cashierPosProvider.loadForUser('cashier@cafe.com');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: cashierPosProvider),
            ChangeNotifierProvider<AuthService>.value(value: cashierAuthService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HeaderBar(isScrolled: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Cashier sees Online Orders nav tab
      expect(find.text('Online Orders'), findsOneWidget);

      // Verify Cashier DOES NOT see desktop online ordering QR shortcut button
      final desktopQrBtnCashier = find.byKey(const ValueKey('desktop_online_order_btn'));
      expect(desktopQrBtnCashier, findsNothing);

      // 2. Store Owner User
      final ownerUser = AppUser(
        uid: 'owner_user_42',
        email: 'owner@cafe.com',
        displayName: 'Store Owner',
        tier: SubscriptionTier.pro,
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );
      final ownerAuthService = AuthService(initialUser: ownerUser);
      final ownerPosProvider = PosProvider();
      await ownerPosProvider.loadForUser('owner@cafe.com');

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: ownerPosProvider),
            ChangeNotifierProvider<AuthService>.value(value: ownerAuthService),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HeaderBar(isScrolled: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Owner sees desktop online ordering shortcut button
      final desktopQrBtnOwner = find.byKey(const ValueKey('desktop_online_order_btn'));
      expect(desktopQrBtnOwner, findsOneWidget);

      // Tap desktop QR button as owner
      await tester.tap(desktopQrBtnOwner);
      await tester.pumpAndSettle();

      // Verify dialog opens and displays Live Orders / Ordering Link tab
      expect(find.byType(OnlineOrderingDialog), findsOneWidget);
      expect(find.text('Ordering Link & QR'), findsOneWidget);

      cashierPosProvider.dispose();
      ownerPosProvider.dispose();
    });

    testWidgets('Customer can edit and modify items in checkout order summary', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final service = OnlineOrderService();
      final storeId = OnlineOrderService.getStoreId('edit_cart_test@cafe.com');
      final List<MenuItem> menu = [
        MenuItem(
          id: 'drink_1',
          name: 'Americano',
          description: 'Rich dark espresso with water',
          icon: '☕',
          price: 90.0,
          category: ItemCategory.coffee,
        ),
        MenuItem(
          id: 'drink_2',
          name: 'Spanish Latte',
          description: 'Handcrafted espresso with sweet milk',
          icon: '☕',
          price: 95.0,
          category: ItemCategory.coffee,
        ),
      ];
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'edit_cart_test@cafe.com',
        storeName: 'Test Coffee Bar',
        isOpen: true,
      );
      await service.publishStoreCatalog(profile: profile, menuItems: menu);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOnlineOrderScreen(storeId: storeId),
        ),
      );
      await tester.pumpAndSettle();

      // Add Americano (tap quick order)
      expect(find.text('Americano'), findsWidgets);
      final americanoAddBtn = find.text('Order').first;
      await tester.tap(americanoAddBtn);
      await tester.pumpAndSettle();

      // Open checkout sheet
      final checkoutBar = find.textContaining('Checkout');
      expect(checkoutBar, findsOneWidget);
      await tester.tap(checkoutBar);
      await tester.pumpAndSettle();

      // Verify Complete Your Order sheet opens
      expect(find.text('Complete Your Order'), findsOneWidget);
      expect(find.text('ORDER SUMMARY'), findsOneWidget);

      // Verify stepper buttons, delete button, and quick actions exist
      final plusBtn = find.byKey(const ValueKey('cart_qty_plus_0'));
      final minusBtn = find.byKey(const ValueKey('cart_qty_minus_0'));
      final deleteBtn = find.byKey(const ValueKey('cart_delete_btn_0'));
      final addMoreBtn = find.byKey(const ValueKey('cart_add_more_btn'));
      expect(plusBtn, findsOneWidget);
      expect(minusBtn, findsOneWidget);
      expect(deleteBtn, findsOneWidget);
      expect(addMoreBtn, findsOneWidget);

      // Increment quantity
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ListView), matching: find.text('2')), findsOneWidget);
      expect(find.textContaining('₱180'), findsWidgets);

      // Decrement quantity back to 1
      await tester.tap(minusBtn);
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ListView), matching: find.text('1')), findsOneWidget);
      expect(find.textContaining('₱90'), findsWidgets);

      // Delete item via red delete button
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();
      expect(find.text('Your cart is empty'), findsOneWidget);

      // Verify Place Order is disabled or reflects empty cart
      expect(find.text('Your Cart is Empty'), findsOneWidget);
    });

    testWidgets('CustomerOnlineOrderScreen renders synchronized store logo and tagline', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dummyLogoBase64 = base64Encode(Uint8List.fromList([1, 2, 3, 4]));
      final customProfile = OnlineStoreProfile(
        storeId: 'branding_sync_store',
        ownerEmail: 'owner@sync.com',
        storeName: 'JC Cafe',
        storeTagline: 'Artisan Roasts & Fresh Treats',
        storeLogoBase64: dummyLogoBase64,
      );

      final List<MenuItem> menu = [
        MenuItem(
          id: 'sync_item_1',
          name: 'Iced Latte',
          description: 'Smooth espresso',
          icon: '☕',
          price: 120.0,
          category: ItemCategory.coffee,
        ),
      ];
      await OnlineOrderService().publishStoreCatalog(profile: customProfile, menuItems: menu);

      await tester.pumpWidget(
        MaterialApp(
          home: CustomerOnlineOrderScreen(storeId: 'branding_sync_store'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JC Cafe'), findsOneWidget);
      expect(find.text('Artisan Roasts & Fresh Treats'), findsOneWidget);
      expect(find.byType(CustomerOnlineOrderScreen), findsOneWidget);

      // Add item and place order to verify tracker screen ALSO displays synced logo and tagline
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Your Name *'), 'Maria');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile Phone Number *'), '09181112233');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      // Verify on Live Order Tracker screen, synced store name & tagline are present
      expect(find.text('LIVE TRACKER'), findsOneWidget);
      expect(find.text('JC Cafe'), findsOneWidget);
      expect(find.text('Artisan Roasts & Fresh Treats'), findsOneWidget);
    });

    testWidgets('PosProvider setCustomLogo propagates to online store profile and Customer UI', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pos = PosProvider();
      await pos.loadForUser('jccafe@store.com');

      final dummyBytes = Uint8List.fromList([10, 20, 30, 40]);
      await pos.setCustomLogo(dummyBytes);

      // Verify PosProvider synced the logo to onlineStoreProfile immediately
      expect(pos.onlineStoreProfile, isNotNull);
      expect(pos.onlineStoreProfile!.storeLogoBase64, equals(base64Encode(dummyBytes)));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: pos),
          ],
          child: const MaterialApp(
            home: CustomerOnlineOrderScreen(storeId: 'jccafe_at_store_com'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomerOnlineOrderScreen), findsOneWidget);
      pos.dispose();
    });

    testWidgets('Owner can edit tagline in OnlineOrderingDialog and syncs to CustomerOnlineOrderScreen', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final pos = PosProvider();
      await pos.loadForUser('tagline_owner@cafe.com');

      final auth = AuthService(
        initialUser: AppUser(
          uid: 'tagline_owner_uid',
          email: 'tagline_owner@cafe.com',
          displayName: 'Owner',
          role: UserRole.owner,
          trialStartDate: DateTime.now(),
        ),
      );

      // Open OnlineOrderingDialog
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<PosProvider>.value(value: pos),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: OnlineOrderingDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Store Controls tab
      await tester.tap(find.text('Store Controls'));
      await tester.pumpAndSettle();

      // Verify Store Name & Tagline section is present
      expect(find.text('STORE NAME & TAGLINE'), findsOneWidget);
      expect(find.text('Save Name & Tagline'), findsOneWidget);

      // Enter new tagline
      final taglineField = find.byKey(const ValueKey('dialog_tagline_field'));
      expect(taglineField, findsOneWidget);
      await tester.enterText(taglineField, 'Specialty Brews & Warm Bites');
      await tester.pumpAndSettle();

      // Tap Save Name & Tagline
      await tester.tap(find.byKey(const ValueKey('dialog_save_branding_btn')));
      await tester.pumpAndSettle();

      // Verify PosProvider and onlineStoreProfile updated
      expect(pos.storeTagline, equals('Specialty Brews & Warm Bites'));
      expect(pos.onlineStoreProfile?.storeTagline, equals('Specialty Brews & Warm Bites'));

      // Now open CustomerOnlineOrderScreen with the same PosProvider
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PosProvider>.value(value: pos),
          ],
          child: const MaterialApp(
            home: CustomerOnlineOrderScreen(storeId: 'tagline_owner_at_cafe_com'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify customer UI renders the updated tagline
      expect(find.text('Specialty Brews & Warm Bites'), findsOneWidget);

      // Test live reactivity: change tagline on PosProvider
      await pos.updateStoreTagline('Fresh Roasted Coffee Daily');
      await tester.pumpAndSettle();

      expect(find.text('Fresh Roasted Coffee Daily'), findsOneWidget);
      pos.dispose();
    });
  });

  group('Customer Order Ready & Out for Delivery Pop-up Modal Tests', () {
    testWidgets('Customer receives celebratory pop-up modal when order status updates to ready', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'ready_modal_test_store';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'modal@cafe.com',
        storeName: 'Celestial Cafe Roasters',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'item_pop_1',
          name: 'Caramel Macchiato',
          description: 'Rich espresso with caramel drizzle',
          icon: '☕',
          price: 90.0,
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

      // 1. Add item to cart
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      // 2. Open checkout modal
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      // 3. Fill in customer details
      await tester.enterText(find.widgetWithText(TextField, 'Your Name *'), 'Juan Dela Cruz');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile Phone Number *'), '09171234567');
      await tester.pumpAndSettle();

      // 4. Place order
      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      // Order is placed, customer is on tracker screen with pending status
      expect(find.text('LIVE TRACKER'), findsOneWidget);

      // Verify ready modal is NOT open yet
      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsNothing);

      // 5. Store cashier updates order status to Ready
      final incoming = await service.fetchIncomingOrders(storeId);
      expect(incoming.isNotEmpty, isTrue);
      final placedOrder = incoming.first;

      await service.updateOrderStatus(
        storeId: storeId,
        orderId: placedOrder.id,
        newStatus: OrderStatus.ready,
      );

      // 6. Advance timer so status polling detects the change
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      // 7. Verify the Pop-up Modal is displayed!
      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsOneWidget);
      expect(find.text(placedOrder.orderNumber), findsWidgets);
      expect(find.text('READY FOR PICKUP'), findsOneWidget);
      expect(find.text('Your Order is Ready for Pickup!'), findsOneWidget);
      expect(find.text('Caramel Macchiato'), findsWidgets);
      expect(find.text('₱90'), findsWidgets);

      // 8. Tap "Got it, Thanks!" to dismiss modal
      await tester.tap(find.byKey(const ValueKey('ready_modal_got_it_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsNothing);

      // 9. Advance timer again: ensure deduplication prevents modal from reopening
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsNothing);
    });

    testWidgets('Customer receives out for delivery modal when delivery order status updates', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'delivery_modal_test_store';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'delivery_modal@cafe.com',
        storeName: 'Celestial Delivery Roasters',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'item_del_1',
          name: 'Iced Vanilla Latte',
          description: 'Smooth cold brew with vanilla',
          icon: '🧋',
          price: 110.0,
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

      // 1. Add item to cart
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();

      // 2. Open checkout modal
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      // 3. Select Delivery order type
      await tester.tap(find.text('Delivery'));
      await tester.pumpAndSettle();

      // Fill in customer details and delivery address
      await tester.enterText(find.widgetWithText(TextField, 'Your Name *'), 'Maria Santos');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile Phone Number *'), '09181234567');
      await tester.enterText(find.widgetWithText(TextField, 'Complete Delivery Address & Landmark *'), '123 Starlight Avenue');
      await tester.pumpAndSettle();

      // Place order
      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      final incoming = await service.fetchIncomingOrders(storeId);
      final placedOrder = incoming.first;

      // 4. Update status to Out For Delivery
      await service.updateOrderStatus(
        storeId: storeId,
        orderId: placedOrder.id,
        newStatus: OrderStatus.outForDelivery,
      );

      // Advance timer
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      // 5. Verify Out for Delivery Modal
      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsOneWidget);
      expect(find.text('OUT FOR DELIVERY'), findsOneWidget);
      expect(find.textContaining('Your rider is on the road heading to 123 Starlight Avenue'), findsOneWidget);

      // Dismiss
      await tester.tap(find.byKey(const ValueKey('ready_modal_got_it_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsNothing);
    });

    testWidgets('Customer browsing menu catalog can tap "View Tracker" from ready modal', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'menu_browse_modal_store';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'browse@cafe.com',
        storeName: 'Celestial Cafe Roasters',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'item_browse_1',
          name: 'Hot Espresso',
          description: 'Pure rich shot',
          icon: '☕',
          price: 75.0,
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

      // 1. Add item & checkout
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Your Name *'), 'Alex Cruz');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile Phone Number *'), '09191234567');
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      // 2. Customer navigates back to menu to browse items
      await tester.tap(find.text('Back to Menu / Order Again'));
      await tester.pumpAndSettle();

      // Verify customer is on menu catalog (recent order banner is showing)
      expect(find.byKey(const ValueKey('recent_order_banner')), findsOneWidget);

      // 3. Store updates order to ready
      final incoming = await service.fetchIncomingOrders(storeId);
      final placedOrder = incoming.first;

      await service.updateOrderStatus(
        storeId: storeId,
        orderId: placedOrder.id,
        newStatus: OrderStatus.ready,
      );

      // 4. Advance timer
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      // 5. Pop-up modal appears over the menu!
      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsOneWidget);
      expect(find.byKey(const ValueKey('ready_modal_view_tracker_btn')), findsOneWidget);

      // 6. Tap "View Tracker"
      await tester.tap(find.byKey(const ValueKey('ready_modal_view_tracker_btn')));
      await tester.pumpAndSettle();

      // 7. Modal closes and customer is seamlessly on Live Order Tracking!
      expect(find.byKey(const ValueKey('order_ready_notification_modal')), findsNothing);
      expect(find.text('LIVE TRACKER'), findsOneWidget);
    });

    testWidgets('Customer can place multiple separate orders, view all orders in modal, and switch between tracking them', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final storeId = 'multi_order_store_test';
      final service = OnlineOrderService();
      final profile = OnlineStoreProfile(
        storeId: storeId,
        ownerEmail: 'multi@cafe.com',
        storeName: 'Multi-Order Cafe',
      );
      final List<MenuItem> menu = [
        MenuItem(
          id: 'item_m_1',
          name: 'Americano',
          description: 'Rich dark espresso',
          icon: '☕',
          price: 90.0,
          category: ItemCategory.coffee,
        ),
        MenuItem(
          id: 'item_m_2',
          name: 'Spanish Latte',
          description: 'Sweet creamy espresso',
          icon: '🥛',
          price: 130.0,
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

      // --- 1. Place First Order (Americano) ---
      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Your Name *'), 'Customer Alice');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile Phone Number *'), '09171112222');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      // Tracker screen shows Order #1
      expect(find.text('LIVE TRACKER'), findsOneWidget);
      final incoming1 = await service.fetchIncomingOrders(storeId);
      expect(incoming1.length, 1);
      final order1Id = incoming1.first.id;
      final order1Number = incoming1.first.orderNumber;
      expect(find.text(order1Number), findsOneWidget);

      // --- 2. Return to Menu to Place Order #2 ---
      await tester.tap(find.text('Back to Menu / Order Again'));
      await tester.pumpAndSettle();

      // --- 3. Place Second Order (Spanish Latte) ---
      await tester.tap(find.text('Add').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Checkout'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Your Name *'), 'Customer Alice');
      await tester.enterText(find.widgetWithText(TextField, 'Mobile Phone Number *'), '09171112222');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Place Order'));
      await tester.pumpAndSettle();

      // Tracker now displays Order #2, and has "Orders (2)" switcher button
      final incoming2 = await service.fetchIncomingOrders(storeId);
      expect(incoming2.length, 2);
      final order2Number = incoming2.first.orderNumber;
      expect(find.text(order2Number), findsOneWidget);
      expect(find.byKey(const ValueKey('tracker_switch_orders_btn')), findsOneWidget);
      expect(find.text('Orders (2)'), findsOneWidget);

      // --- 4. Return to Menu and Verify Header Bag shows Counter Badge '2' ---
      await tester.tap(find.text('Back to Menu / Order Again'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('header_bag_count_badge')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.byKey(const ValueKey('banner_view_all_orders_btn')), findsOneWidget);
      expect(find.text('All (2)'), findsOneWidget);

      // --- 5. Tap Bag Icon to Open "Your Orders" Dialog ---
      await tester.tap(find.byKey(const ValueKey('header_order_tracker_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recent_orders_dialog')), findsOneWidget);
      expect(find.text('Your Orders'), findsOneWidget);
      expect(find.text('2 orders placed recently'), findsOneWidget);
      expect(find.text(order1Number), findsOneWidget);
      expect(find.text(order2Number), findsOneWidget);

      // --- 6. Tap "Track Live" on Order #1 ---
      final trackOrderBtn = find.byKey(ValueKey('track_order_btn_$order1Id'));
      await tester.tap(trackOrderBtn);
      await tester.pumpAndSettle();

      // Verify tracker switched to Order #1
      expect(find.byKey(const ValueKey('recent_orders_dialog')), findsNothing);
      expect(find.text('LIVE TRACKER'), findsOneWidget);
      expect(find.text(order1Number), findsOneWidget);
    });
  });
}



