import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/main.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/auth_service.dart';
import 'package:celestial_pos/widgets/customization_dialog.dart';
import 'package:celestial_pos/widgets/header_bar.dart';
import 'package:celestial_pos/widgets/admin_management_dialog.dart';
import 'package:celestial_pos/widgets/create_pin_dialog.dart';
import 'package:celestial_pos/widgets/upgrade_pro_dialog.dart';
import 'package:celestial_pos/widgets/signature_banner_dialog.dart';
import 'package:celestial_pos/theme/celestial_theme.dart';
import 'package:celestial_pos/screens/login_screen.dart';
import 'package:celestial_pos/widgets/trial_expired_dialog.dart';
import 'package:celestial_pos/widgets/cart_panel.dart';
import 'package:celestial_pos/widgets/top_notification.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TrialExpiredDialog.isShowing = false;
  });

  testWidgets('CelestialCafePosApp launches into LoginScreen when logged out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CelestialCafePosApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Login Screen — Google Sign In / Sign Up & PIN Sign In
    expect(find.text('JC POS SYSTEM'), findsOneWidget);
    expect(find.textContaining('Sign In with PIN'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);
    expect(find.text('Launch Free Trial Instantly'), findsNothing);
    expect(find.text('Sign In with Google'), findsNothing);
    expect(find.text('Sign Up with Google'), findsOneWidget);
    expect(find.text('Developed by JC Celestial'), findsOneWidget);
    expect(find.textContaining('Free Trial Included'), findsNothing);
  });

  testWidgets('Celestial Cafe POS app launches into MainWorkstationScaffold on Desktop when logged in', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final loggedInUser = AppUser(
      uid: 'cashier_desktop_1',
      email: 'barista@celestialcafe.com',
      displayName: 'Celestial Barista',
      tier: SubscriptionTier.trial,
      trialStartDate: DateTime.now(),
    );
    final authService = AuthService(initialUser: loggedInUser);

    await tester.pumpWidget(CelestialCafePosApp(authService: authService));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Brand & Pure POS Navigation Stations
    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('Cozy&Classic'), findsOneWidget);
    expect(find.text('POS Station'), findsOneWidget);
    expect(find.text('Order History'), findsOneWidget);
    expect(find.text('Menu & Stock'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);

    // Verify removed multi-station tabs do not exist
    expect(find.text('Barista / KDS'), findsNothing);
    expect(find.text('Table QR'), findsNothing);

    // Verify User Account Chip & Tier Indicator
    expect(find.textContaining('TRIAL'), findsOneWidget);

    // Verify Official Menu Items & Initial Order Tray
    expect(find.text('Current Order'), findsOneWidget);
    expect(find.text('Your Tray is Empty'), findsOneWidget);
    expect(find.text('Spanish Latte'), findsOneWidget);
    expect(find.text('Americano'), findsOneWidget);
  });

  testWidgets('Celestial Cafe POS app renders on Mobile screen with 4 Bottom Nav Destinations', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final loggedInUser = AppUser(
      uid: 'cashier_mobile_1',
      email: 'barista@celestialcafe.com',
      displayName: 'Celestial Barista',
      tier: SubscriptionTier.trial,
      trialStartDate: DateTime.now(),
    );
    final authService = AuthService(initialUser: loggedInUser);

    await tester.pumpWidget(CelestialCafePosApp(authService: authService));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Mobile Header & Mobile Bottom Nav Destinations
    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);

    // Verify removed KDS does not exist on mobile nav
    expect(find.text('KDS'), findsNothing);

    // Verify Mobile Menu Grid
    expect(find.text('Spanish Latte'), findsOneWidget);
    expect(find.text('Americano'), findsOneWidget);
  });

  test('PosProvider starts clean and processes standalone POS checkout', () {
    final provider = PosProvider();

    // Starts 100% clean
    expect(provider.orders.isEmpty, true);
    expect(provider.todayOrdersCount, 0);
    expect(provider.todayTotalSales, 0.0);
    expect(provider.cart.isEmpty, true);
    expect(provider.cartItemCount, 0);

    final item = provider.menuItems.first; // Americano ₱90
    final initialStock = item.stockCount;

    // Add item to cart with Extra Espresso Shot (₱25)
    provider.addToCart(
      item,
      quantity: 2,
      customizations: [
        SelectedCustomization(groupTitle: 'Add-ons & Extras', optionName: 'Extra Espresso Shot', extraPrice: 25.00),
      ],
      notes: 'Extra hot',
    );

    expect(provider.cart.length, 1);
    expect(provider.cartItemCount, 2);
    expect(provider.cartSubtotal, (item.price + 25.00) * 2);

    // Apply 10% discount
    provider.applyDiscount(percentage: 10);
    expect(provider.discountPercentage, 10.0);
    expect(provider.cartDiscountAmount, provider.cartSubtotal * 0.10);

    // Checkout order with cash ₱500 bill
    final createdOrder = provider.completeCheckout(
      paymentMethod: PaymentMethod.cash,
      amountTendered: 500.0,
      specialOrderNotes: 'VIP patron',
    );

    // Verify order is created and cart is cleared
    expect(provider.orders.length, 1);
    expect(createdOrder.items.length, 1);
    expect(createdOrder.paymentMethod, PaymentMethod.cash);
    expect(provider.cart.isEmpty, true);
    expect(provider.menuItems.first.stockCount, initialStock - 2);

    // Verify order is recorded in history as completed
    expect(provider.orders.first.id, createdOrder.id);
    expect(provider.todayOrdersCount, 1);
    expect(provider.todayTotalSales, createdOrder.totalAmount);
    expect(provider.completedOrders.any((o) => o.id == createdOrder.id), true);

    // Transition status to preparing -> ready -> completed
    provider.updateOrderStatus(createdOrder.id, OrderStatus.preparing);
    expect(provider.preparingOrders.any((o) => o.id == createdOrder.id), true);

    provider.updateOrderStatus(createdOrder.id, OrderStatus.ready);
    expect(provider.readyOrders.any((o) => o.id == createdOrder.id), true);

    provider.updateOrderStatus(createdOrder.id, OrderStatus.completed);
    expect(provider.completedOrders.any((o) => o.id == createdOrder.id), true);
  });

  test('PosProvider local persistence preserves data across sessions', () async {
    final provider1 = PosProvider();
    final firstItem = provider1.menuItems.first;

    // Modify stock
    provider1.updateStockCount(firstItem.id, 77);

    // Create an order
    provider1.addToCart(firstItem, quantity: 1);
    final order = provider1.completeCheckout(
      paymentMethod: PaymentMethod.mobilePay,
      amountTendered: 90.0,
    );

    // Simulate reopening the app with a fresh provider instance
    final provider2 = PosProvider();
    await Future.delayed(const Duration(milliseconds: 50));

    expect(provider2.orders.length, 1);
    expect(provider2.orders.first.id, order.id);
    expect(provider2.menuItems.firstWhere((m) => m.id == firstItem.id).stockCount, 76);
  });

  test('PosProvider item price settings and price updates', () async {
    final provider = PosProvider();
    final item = provider.menuItems.first;
    expect(item.price, 90.00);

    // Update Americano price to ₱99
    provider.updateItemPrice(item.id, 99.00);
    expect(provider.menuItems.first.price, 99.00);

    // Bulk adjust coffee prices (+₱10)
    provider.bulkAdjustPrices(flatAmount: 10.0, category: ItemCategory.coffee);
    expect(provider.menuItems.first.price, 109.00);
  });

  test('PosProvider inventory management and stock toggles', () {
    final provider = PosProvider();
    final firstItem = provider.menuItems.first;

    provider.updateStockCount(firstItem.id, 100);
    expect(provider.menuItems.first.stockCount, 100);
    expect(provider.menuItems.first.inStock, true);

    provider.toggleItemStock(firstItem.id);
    expect(provider.menuItems.first.inStock, false);

    provider.toggleItemStock(firstItem.id);
    expect(provider.menuItems.first.inStock, true);
  });

  test('AuthService manages Trial and Pro subscription tiers, Admin and Custom Trials', () async {
    final auth = AuthService();
    await Future.delayed(const Duration(milliseconds: 50));

    // Initially logged out
    expect(auth.isLoggedIn, false);

    // Admin sets default trial duration to 45 days (admin-only control)
    await auth.setDefaultTrialDays(45);
    expect(auth.defaultTrialDays, 45);

    // Instant Free Trial now uses admin-configured duration (no user override)
    await auth.continueWithTrial(customEmail: 'test.barista@celestial.com');
    expect(auth.isLoggedIn, true);
    expect(auth.currentUser?.email, 'test.barista@celestial.com');
    expect(auth.currentTier, SubscriptionTier.trial);
    expect(auth.isPro, false);
    expect(auth.currentUser?.trialDaysRemaining, 45);

    // Non-admin cannot modify default trial duration
    await auth.setDefaultTrialDays(3);
    expect(auth.defaultTrialDays, 45);

    // Non-admin cannot self-upgrade to Pro
    final unauthorizedUpgrade = await auth.upgradeToPro();
    expect(unauthorizedUpgrade, false);
    expect(auth.isPro, false);
    expect(auth.currentTier, SubscriptionTier.trial);

    // Non-admin cannot toggle tier
    final unauthorizedToggle = await auth.toggleTier();
    expect(unauthorizedToggle, false);
    expect(auth.isPro, false);

    // Admin Sign In & Account Management (Admin authorization succeeds)
    await auth.signInAsAdmin(email: 'adminpogi6@gmail.com');
    expect(auth.isAdmin, true);
    expect(auth.isPro, true);

    // Admin-authorized update to 3 days
    await auth.setDefaultTrialDays(3);
    expect(auth.defaultTrialDays, 3);

    // Admin can toggle tier
    await auth.toggleTier();
    expect(auth.isPro, false);
    await auth.toggleTier();
    expect(auth.isPro, true);

    // Add a managed station with custom trial days (30 days)
    await auth.addManagedAccount(
      email: 'patio.cashier@gmail.com',
      displayName: 'Patio Cashier',
      tier: SubscriptionTier.trial,
      trialDays: 30,
    );
    final station = auth.managedAccounts.firstWhere((a) => a.email == 'patio.cashier@gmail.com');
    expect(station.customTrialDays, 30);
    expect(station.isPro, false);

    // Admin switches station to Pro
    await auth.updateAccountTier(station.uid, SubscriptionTier.pro);
    final updatedStation = auth.managedAccounts.firstWhere((a) => a.uid == station.uid);
    expect(updatedStation.isPro, true);

    // Admin switches back to custom 60-day trial
    await auth.updateAccountTier(station.uid, SubscriptionTier.trial);
    await auth.updateAccountCustomTrial(station.uid, 60);
    final reUpdatedStation = auth.managedAccounts.firstWhere((a) => a.uid == station.uid);
    expect(reUpdatedStation.isPro, false);
    expect(reUpdatedStation.customTrialDays, 60);

    // Setting global default to 5 days does not overwrite custom trial override
    await auth.setDefaultTrialDays(5);
    final stationRefreshed = auth.managedAccounts.firstWhere((a) => a.uid == station.uid);
    expect(stationRefreshed.customTrialDays, 60);
    expect(stationRefreshed.hasCustomTrial, true);

    // Sign out
    await auth.signOut();
    expect(auth.isLoggedIn, false);
    expect(auth.currentUser, isNull);
  });

  test('AuthService Gmail + PIN registration and sign-in flow', () async {
    final auth = AuthService();
    await Future.delayed(const Duration(milliseconds: 50));

    // Register new account with Gmail + PIN
    final regResult = await auth.registerWithPin(
      email: 'newcashier@gmail.com',
      pin: '1234',
    );
    expect(regResult, true);
    expect(auth.isLoggedIn, true);
    expect(auth.currentUser?.email, 'newcashier@gmail.com');
    expect(auth.isEmailRegistered('newcashier@gmail.com'), true);

    // Duplicate registration should fail
    await auth.signOut();
    final dupResult = await auth.registerWithPin(
      email: 'newcashier@gmail.com',
      pin: '9999',
    );
    expect(dupResult, false);
    expect(auth.errorMessage, contains('already exists'));

    // Sign in with correct PIN
    final signInResult = await auth.signInWithPin(
      email: 'newcashier@gmail.com',
      pin: '1234',
    );
    expect(signInResult, true);
    expect(auth.isLoggedIn, true);
    expect(auth.currentUser?.email, 'newcashier@gmail.com');

    // Sign in with wrong PIN should fail
    await auth.signOut();
    final wrongPinResult = await auth.signInWithPin(
      email: 'newcashier@gmail.com',
      pin: '0000',
    );
    expect(wrongPinResult, false);
    expect(auth.errorMessage, contains('Incorrect PIN'));

    // Sign in with unknown email should fail
    final unknownResult = await auth.signInWithPin(
      email: 'nobody@gmail.com',
      pin: '1234',
    );
    expect(unknownResult, false);
    expect(auth.errorMessage, contains('No account found'));

    // Admin resets PIN
    final resetResult = await auth.resetAccountPin('newcashier@gmail.com', '5678');
    expect(resetResult, true);

    // Sign in with new PIN succeeds
    final newPinResult = await auth.signInWithPin(
      email: 'newcashier@gmail.com',
      pin: '5678',
    );
    expect(newPinResult, true);

    // Register exclusive admin account adminpogi6@gmail.com with PIN
    final adminReg = await auth.registerWithPin(
      email: 'adminpogi6@gmail.com',
      pin: '8888',
    );
    expect(adminReg, true);
    expect(auth.isAdmin, true);
    expect(auth.isPro, true);
    expect(auth.currentUser?.email, 'adminpogi6@gmail.com');

    // Verify other emails (even with admin in name) do not get admin status
    await auth.signOut();
    final regularReg = await auth.registerWithPin(
      email: 'otheradmin@gmail.com',
      pin: '1111',
    );
    expect(regularReg, true);
    expect(auth.isAdmin, false);

    await auth.signOut();
    expect(auth.isLoggedIn, false);
  });

  test('AuthService singleton, AppUser idToken support, and token utilities', () async {
    final auth = AuthService.instance;
    expect(auth, isNotNull);

    // Verify AppUser with idToken serialization
    final testUser = AppUser(
      uid: 'google_12345',
      email: 'cashier.pos@gmail.com',
      displayName: 'POS Cashier',
      idToken: 'fake_jwt_token_payload',
      trialStartDate: DateTime.now(),
    );
    expect(testUser.idToken, 'fake_jwt_token_payload');

    final json = testUser.toJson();
    expect(json['idToken'], 'fake_jwt_token_payload');

    final reconstructed = AppUser.fromJson(json);
    expect(reconstructed.idToken, 'fake_jwt_token_payload');

    final copied = reconstructed.copyWith(idToken: 'refreshed_token');
    expect(copied.idToken, 'refreshed_token');

    // Test static isCurrentUserAdmin helper
    expect(AuthService.isCurrentUserAdmin(null), false);
    expect(AuthService.isCurrentUserAdmin('adminpogi6@gmail.com'), true);
    expect(AuthService.isCurrentUserAdmin('regular.user@gmail.com'), false);

    // Set testing user and verify state
    auth.setLoggedInUserForTesting(copied);
    expect(auth.isSignedIn, true);
    expect(auth.currentUser?.idToken, 'refreshed_token');

    await auth.signOut();
    expect(auth.isSignedIn, false);
  });


  testWidgets('AdminManagementDialog renders overview stats and allows account management', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final adminUser = AppUser(
      uid: 'admin_1',
      email: 'adminpogi6@gmail.com',
      displayName: 'Master Administrator',
      isAdmin: true,
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now(),
    );
    final authService = AuthService(initialUser: adminUser);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<PosProvider>(create: (_) => PosProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminManagementDialog(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Admin Header and Stats
    expect(find.text('ADMIN LICENSE & ACCOUNT MANAGER'), findsOneWidget);
    expect(find.text('Total Stations'), findsOneWidget);
    expect(find.text('Pro Enterprise'), findsOneWidget);
    expect(find.text('Add Station'), findsOneWidget);
    expect(find.text('+ Authorize Admin Gmail'), findsOneWidget);
  });

  testWidgets('AdminManagementDialog renders responsive layout on mobile viewport without text wrapping or overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final adminUser = AppUser(
      uid: 'admin_1',
      email: 'adminpogi6@gmail.com',
      displayName: 'Master Administrator',
      isAdmin: true,
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now(),
    );
    final authService = AuthService(initialUser: adminUser);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: authService),
          ChangeNotifierProvider<PosProvider>(create: (_) => PosProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AdminManagementDialog(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Admin Header, metrics, search bar, and station email display
    expect(find.text('ADMIN LICENSE & ACCOUNT MANAGER'), findsOneWidget);
    expect(find.text('Total Stations'), findsOneWidget);
    expect(find.text('Pro Enterprise'), findsOneWidget);
    expect(find.text('Add Station'), findsOneWidget);
    expect(find.text('+ Admin Gmail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomizationDialog renders rich UI and handles options and add to cart', (WidgetTester tester) async {
    final item = initialCelestialMenu.first; // Americano (₱90)
    int addedQuantity = 0;
    List<SelectedCustomization> addedCustomizations = [];
    String? addedNotes;

    await tester.pumpWidget(
      MaterialApp(
        theme: CelestialTheme.themeData,
        home: Scaffold(
          body: CustomizationDialog(
            item: item,
            onAddToCart: (qty, customs, notes) {
              addedQuantity = qty;
              addedCustomizations = customs;
              addedNotes = notes;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Price Badge
    expect(find.text('Americano'), findsOneWidget);
    expect(find.text('₱90'), findsWidgets);

    // Verify Temperature Section has Hot and Iced
    expect(find.text('Hot'), findsOneWidget);
    expect(find.text('Iced'), findsOneWidget);

    // Tap "Hot"
    await tester.tap(find.text('Hot'));
    await tester.pumpAndSettle();

    // Toggle an Add-on: "Extra Espresso Shot"
    expect(find.text('Extra Espresso Shot'), findsOneWidget);
    await tester.tap(find.text('Extra Espresso Shot'));
    await tester.pumpAndSettle();

    // Stepper +
    await tester.tap(find.byKey(const Key('customization_qty_plus')));
    await tester.pumpAndSettle();

    // Tap Add to Cart
    await tester.tap(find.textContaining('Add 2'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(addedQuantity, 2);
    expect(addedNotes, isNull);
    expect(addedCustomizations.any((c) => c.optionName == 'Hot'), true);
    expect(addedCustomizations.any((c) => c.optionName == 'Extra Espresso Shot'), true);
  });

  testWidgets('HeaderBar renders liquid glass with smooth animated states when scrolled', (WidgetTester tester) async {
    final pos = PosProvider();
    final auth = AuthService();

    // Unscrolled state
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PosProvider>.value(value: pos),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HeaderBar(
              isScrolled: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('POS Station'), findsOneWidget);

    // Scrolled state
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PosProvider>.value(value: pos),
          ChangeNotifierProvider<AuthService>.value(value: auth),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HeaderBar(
              isScrolled: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CELESTIAL'), findsOneWidget);
    expect(find.text('POS Station'), findsOneWidget);
  });

  test('AuthService setPinForUser stores PIN, updates hasPin, and permits signInWithPin', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    expect(auth.hasPin('newuser@gmail.com'), false);

    // Fails on non-4 digit PIN
    final failResult = await auth.setPinForUser(email: 'newuser@gmail.com', pin: '12');
    expect(failResult, false);
    expect(auth.hasPin('newuser@gmail.com'), false);

    // Succeeds with 4-digit PIN
    final successResult = await auth.setPinForUser(email: 'newuser@gmail.com', pin: '4321');
    expect(successResult, true);
    expect(auth.hasPin('newuser@gmail.com'), true);

    // Can sign in using Gmail + PIN
    final signInResult = await auth.signInWithPin(email: 'newuser@gmail.com', pin: '4321');
    expect(signInResult, true);
    expect(auth.isLoggedIn, true);
    expect(auth.currentUser?.email, 'newuser@gmail.com');

  });

  testWidgets('CreatePinDialog renders and saves 4-digit PIN', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: const MaterialApp(
          home: Scaffold(
            body: CreatePinDialog(
              email: 'googleuser@gmail.com',
              displayName: 'Google User',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify dialog header and inputs
    expect(find.text('Create Station PIN'), findsOneWidget);
    expect(find.textContaining('googleuser@gmail.com'), findsOneWidget);
    expect(find.text('Save Station PIN'), findsOneWidget);
    expect(find.text('Set Up Later'), findsOneWidget);

    // Enter PIN in both fields
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.at(0), '7890');
    await tester.enterText(textFields.at(1), '7890');
    await tester.pump();

    // Tap Save Station PIN
    await tester.tap(find.text('Save Station PIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.hasPin('googleuser@gmail.com'), true);
  });

  test('AuthService setPinForUser updates existing PIN when isUpdate is true and preserves active session', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    // 1. Initial PIN creation
    final created = await auth.setPinForUser(email: 'activecashier@gmail.com', pin: '1234');
    expect(created, true);
    expect(auth.hasPin('activecashier@gmail.com'), true);
    expect(auth.isLoggedIn, true);
    expect(auth.currentUser?.email, 'activecashier@gmail.com');

    // 2. Update PIN to '5678' with isUpdate: true
    final updated = await auth.setPinForUser(
      email: 'activecashier@gmail.com',
      pin: '5678',
      isUpdate: true,
    );
    expect(updated, true);
    // User remains logged in!
    expect(auth.isLoggedIn, true);
    expect(auth.currentUser?.email, 'activecashier@gmail.com');

    // 3. Old PIN '1234' no longer works, new PIN '5678' works
    await auth.signOut();
    expect(auth.isLoggedIn, false);

    final oldFail = await auth.signInWithPin(email: 'activecashier@gmail.com', pin: '1234');
    expect(oldFail, false);

    final newSuccess = await auth.signInWithPin(email: 'activecashier@gmail.com', pin: '5678');
    expect(newSuccess, true);
    expect(auth.isLoggedIn, true);
  });

  testWidgets('CreatePinDialog in update mode updates PIN and succeeds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.setPinForUser(email: 'manager@gmail.com', pin: '1111');

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: const MaterialApp(
          home: Scaffold(
            body: CreatePinDialog(
              email: 'manager@gmail.com',
              displayName: 'Manager',
              isUpdate: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify update mode texts
    expect(find.text('Update Station PIN'), findsOneWidget);
    expect(find.text('Enter New 4-Digit PIN'), findsOneWidget);
    expect(find.text('Confirm New 4-Digit PIN'), findsOneWidget);
    expect(find.text('Update PIN'), findsOneWidget);

    // Enter new PIN 9999 in both fields
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2));

    await tester.enterText(textFields.at(0), '9999');
    await tester.enterText(textFields.at(1), '9999');
    await tester.pump();

    // Tap Update PIN
    await tester.tap(find.text('Update PIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify PIN was updated
    expect(auth.verifyPin('manager@gmail.com', '9999'), true);
    expect(auth.verifyPin('manager@gmail.com', '1111'), false);
  });

  testWidgets('UpgradeProDialog and HeaderBar render dynamic trial text synced with admin default', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.setDefaultTrialDays(3);

    final trialUser = AppUser(
      uid: 'trial_sync_1',
      email: 'trial.cashier@gmail.com',
      displayName: 'Trial Cashier',
      tier: SubscriptionTier.trial,
      trialStartDate: DateTime.now(),
      customTrialDays: 3,
      hasCustomTrial: false,
    );
    auth.setLoggedInUserForTesting(trialUser);

    // 1. Verify UpgradeProDialog shows 3D FREE TRIAL and 3-Day Free Trial
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<PosProvider>(create: (_) => PosProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: UpgradeProDialog(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('3D FREE TRIAL'), findsOneWidget);
    expect(find.text('3-Day Free Trial'), findsOneWidget);
    expect(find.textContaining('3 days remaining on trial'), findsOneWidget);

    // 2. Verify HeaderBar on mobile displays 3D TRIAL chip
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<PosProvider>(create: (_) => PosProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HeaderBar(isScrolled: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('3D TRIAL'), findsOneWidget);
  });

  test('Pro accounts are never given isAdmin=true and cannot call admin methods', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    final proUser = AppUser(
      uid: 'pro_user_test',
      email: 'pro@celestialcafe.com',
      displayName: 'Pro User',
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now(),
      isAdmin: false,
    );
    auth.setLoggedInUserForTesting(proUser);

    expect(auth.isPro, true);
    expect(auth.isAdmin, false);

    // Pro-only account cannot add managed accounts (admin-only operation)
    final countBefore = auth.managedAccounts.length;
    await auth.addManagedAccount(
      email: 'unauthorized@celestialcafe.com',
      displayName: 'Unauthorized',
      tier: SubscriptionTier.trial,
    );
    // List must not have grown — Pro user is silently rejected
    expect(auth.managedAccounts.length, countBefore);
    expect(
      auth.managedAccounts.any((a) => a.email == 'unauthorized@celestialcafe.com'),
      false,
    );

    // Pro user cannot self-upgrade
    final upgradeResult = await auth.upgradeToPro();
    expect(upgradeResult, false);

    // Pro user cannot toggle tier
    final toggleResult = await auth.toggleTier();
    expect(toggleResult, false);
  });

  testWidgets('Admin portal button is hidden for Pro-only accounts and the dialog refuses access', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final proUser = AppUser(
      uid: 'pro_user_test_2',
      email: 'pro2@celestialcafe.com',
      displayName: 'Pro User 2',
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now(),
      isAdmin: false,
    );
    final auth = AuthService(initialUser: proUser);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<PosProvider>(create: (_) => PosProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: HeaderBar(isScrolled: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Admin portal button should be absent for Pro-only accounts
    expect(find.byTooltip('Admin Portal'), findsNothing);
  });

  test('PosProvider signature banner customization, persistence, and reset', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = PosProvider();
    await Future.delayed(const Duration(milliseconds: 100));

    // Verify defaults
    expect(provider.signatureBannerEnabled, true);
    expect(provider.signatureBannerBadge, 'CELESTIAL SIGNATURE CRAFT');
    expect(provider.signatureBannerTitle, 'Celestial Signature Latte');
    expect(provider.signatureBannerSubtitle, 'House specialty handcrafted celestial latte blend with silky sweet foam');
    expect(provider.signatureBannerButtonText, 'Order');
    expect(provider.signatureBannerItemId, 'nesp_1');
    expect(provider.hasCustomSignatureBannerImage, false);

    // Update banner customization
    await provider.updateSignatureBanner(
      enabled: true,
      badge: 'TODAY\'S SPECIAL',
      title: 'Artisan Matcha Latte',
      subtitle: 'Premium authentic stone-ground green tea whisked with silky milk',
      buttonText: 'Order Matcha',
      itemId: 'nesp_2',
    );

    expect(provider.signatureBannerBadge, 'TODAY\'S SPECIAL');
    expect(provider.signatureBannerTitle, 'Artisan Matcha Latte');
    expect(provider.signatureBannerSubtitle, 'Premium authentic stone-ground green tea whisked with silky milk');
    expect(provider.signatureBannerButtonText, 'Order Matcha');
    expect(provider.signatureBannerItemId, 'nesp_2');

    // Verify persistence across new instance
    final restoredProvider = PosProvider();
    await Future.delayed(const Duration(milliseconds: 100));
    expect(restoredProvider.signatureBannerBadge, 'TODAY\'S SPECIAL');
    expect(restoredProvider.signatureBannerTitle, 'Artisan Matcha Latte');
    expect(restoredProvider.signatureBannerItemId, 'nesp_2');

    // Reset to defaults
    await restoredProvider.resetSignatureBanner();
    expect(restoredProvider.signatureBannerBadge, 'CELESTIAL SIGNATURE CRAFT');
    expect(restoredProvider.signatureBannerTitle, 'Celestial Signature Latte');
    expect(restoredProvider.signatureBannerItemId, 'nesp_1');
  });

  testWidgets('SignatureBannerDialog renders banner customization and live preview', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final pos = PosProvider();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));

    await tester.pumpWidget(
      ChangeNotifierProvider<PosProvider>.value(
        value: pos,
        child: const MaterialApp(
          home: Scaffold(
            body: SignatureBannerDialog(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Customize Signature Banner'), findsOneWidget);
    expect(find.text('LIVE BANNER PREVIEW'), findsOneWidget);
    expect(find.text('Display Hero Banner on POS'), findsOneWidget);
  });

  testWidgets('CelestialCafePosApp displays signature banner on workstation and customize action', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final loggedInUser = AppUser(
      uid: 'banner_user_1',
      email: 'owner@celestialcafe.com',
      displayName: 'Cafe Owner',
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now(),
    );
    final auth = AuthService(initialUser: loggedInUser);

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('CELESTIAL SIGNATURE CRAFT'), findsOneWidget);
    expect(find.text('Celestial Signature Latte'), findsWidgets);
    expect(find.byTooltip('Customize Signature Banner'), findsOneWidget);
  });

  test('Admin custom trial input syncs immediately to matching user and un-expires accounts', () async {
    SharedPreferences.setMockInitialValues({});
    final adminUser = AppUser(
      uid: 'admin_test_1',
      email: 'adminpogi6@gmail.com',
      displayName: 'Admin User',
      isAdmin: true,
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now(),
    );
    final auth = AuthService(initialUser: adminUser);

    // 1. Add an expired cashier station (started 30 days ago, 14 days default)
    await auth.addManagedAccount(
      email: 'cashier.test@celestialcafe.com',
      displayName: 'Cashier Station',
      tier: SubscriptionTier.trial,
    );
    final cashierStation = auth.managedAccounts.firstWhere((a) => a.email == 'cashier.test@celestialcafe.com');

    // Manually age the account to simulate an expired trial
    final agedCashier = cashierStation.copyWith(
      trialStartDate: DateTime.now().subtract(const Duration(days: 35)),
    );
    await auth.setPinForUser(email: agedCashier.email, pin: '1111');
    auth.setLoggedInUserForTesting(agedCashier);

    expect(auth.currentUser?.isTrialExpired, true);
    expect(auth.currentUser?.trialDaysRemaining, 0);

    // 2. Admin logs in and inputs 20 custom trial days for this cashier
    auth.setLoggedInUserForTesting(adminUser);
    expect(auth.isAdmin, true);

    await auth.updateAccountCustomTrial(cashierStation.uid, 20);

    // Check managed account was un-expired and now has 20 days remaining
    final updatedManaged = auth.managedAccounts.firstWhere((a) => a.uid == cashierStation.uid);
    expect(updatedManaged.hasCustomTrial, true);
    expect(updatedManaged.customTrialDays, 20);
    expect(updatedManaged.isTrialExpired, false);
    expect(updatedManaged.trialDaysRemaining, 20);

    // 3. Cashier logs back in with PIN: verify session is synced with admin's input
    auth.setLoggedInUserForTesting(agedCashier);
    final pinSuccess = await auth.signInWithPin(email: 'cashier.test@celestialcafe.com', pin: '1111');
    expect(pinSuccess, true);
    expect(auth.currentUser?.isTrialExpired, false);
    expect(auth.currentUser?.trialDaysRemaining, 20);
    expect(auth.currentUser?.customTrialDays, 20);
    expect(auth.currentUser?.hasCustomTrial, true);
  });

  test('AuthService registered PIN flow for Gmail login', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.setPinForUser(email: 'station1@gmail.com', pin: '1234');

    expect(auth.isEmailRegistered('station1@gmail.com'), true);
    expect(auth.hasPin('station1@gmail.com'), true);

    // Fails on incorrect PIN
    final failSignIn = await auth.signInWithPin(email: 'station1@gmail.com', pin: '9999');
    expect(failSignIn, false);
    expect(auth.errorMessage, 'Incorrect PIN. Please try again.');

    // Succeeds on registered PIN
    final successSignIn = await auth.signInWithPin(email: 'station1@gmail.com', pin: '1234');
    expect(successSignIn, true);
    expect(auth.currentUser?.email, 'station1@gmail.com');
    expect(auth.lastStationEmail, 'station1@gmail.com');
  });

  testWidgets('LoginScreen displays Station Account Card and PIN only when Gmail is remembered', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'celestial_last_station_email': 'barista.station@gmail.com',
      'celestial_auth_pin_credentials': '{"barista.station@gmail.com":"YmFyaXN0YS5zdGF0aW9uQGdtYWlsLmNvbToxMjM0"}',
    });

    final auth = AuthService();
    auth.setStationEmailForTesting('barista.station@gmail.com');

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Station Account Card is displayed with email and Switch button
    expect(find.text('Station Gmail Account'), findsOneWidget);
    expect(find.text('barista.station@gmail.com'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Ready to Sign In'), findsOneWidget);

    // Verify email TextField is NOT rendered (user does NOT need to type email)
    expect(find.text('your.email@gmail.com'), findsNothing);

    // Verify PIN field and Sign In to Station button are rendered
    expect(find.text('Registered 4-Digit PIN'), findsOneWidget);
    expect(find.text('Sign In to Station'), findsOneWidget);

    // Tapping Switch clears remembered email and reveals the email TextField
    await tester.tap(find.text('Switch'));
    await tester.pump();

    expect(find.text('Station Gmail Account'), findsNothing);
    expect(find.textContaining('Gmail Address'), findsOneWidget);
  });

  testWidgets('MainWorkstationScaffold clears leftover dialogs upon login initialization', (WidgetTester tester) async {
    final auth = AuthService();
    auth.setLoggedInUserForTesting(
      AppUser(
        uid: 'test_cashier_uid',
        email: 'jccelestial04@gmail.com',
        displayName: 'Jc Celestial',
        tier: SubscriptionTier.trial,
        trialStartDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pumpAndSettle();

    // Verify MainWorkstationScaffold is displayed
    expect(find.byType(MainWorkstationScaffold), findsOneWidget);
    expect(find.text('Register Station PIN'), findsNothing);
    expect(find.text('Registering...'), findsNothing);
    expect(find.text('jccelestial04@gmail.com'), findsOneWidget);
  });

  test('AuthService is configured with user Firebase Realtime Database endpoint', () {
    expect(
      AuthService.realtimeDbUrl,
      'https://celestial-cafe-pos-2026-default-rtdb.asia-southeast1.firebasedatabase.app',
    );
  });

  testWidgets('HeaderBar renders clean header and Account Modal with terminal sign out', (WidgetTester tester) async {
    final auth = AuthService(
      initialUser: AppUser(
        uid: 'test_cashier_uid',
        email: 'cashier@celestialcafe.com',
        displayName: 'Celestial Cashier',
        role: UserRole.cashier,
        tier: SubscriptionTier.trial,
        trialStartDate: DateTime.now(),
      ),
    );

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pumpAndSettle();

    // Verify clean header: Settings icon and Account Chip exist, redundant loose sign out is removed
    expect(find.byIcon(Icons.settings_outlined), findsWidgets);
    expect(find.text('cashier@celestialcafe.com'), findsOneWidget);

    // Tap the user account chip to open Account Modal
    await tester.tap(find.text('cashier@celestialcafe.com'));
    await tester.pumpAndSettle();

    // Verify Account Modal opens with station details
    expect(find.text('CASHIER STATION'), findsOneWidget);
    expect(find.text('Sign Out Terminal'), findsOneWidget);

    // Tap Sign Out Terminal inside modal
    final modalSignOutBtn = find.byKey(const Key('modal_sign_out_button'));
    expect(modalSignOutBtn, findsOneWidget);
    await tester.tap(modalSignOutBtn);
    await tester.pumpAndSettle();

    // Verify user is signed out and LoginScreen is displayed
    expect(auth.isLoggedIn, false);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('LoginScreen and modals are fully responsive on narrow mobile viewport (360x640) without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CelestialCafePosApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify brand and components fit without overflow
    expect(find.text('JC POS SYSTEM'), findsOneWidget);
    expect(find.text('Sign In with Google'), findsNothing);
    expect(find.text('Sign Up with Google'), findsOneWidget);
    expect(find.textContaining('Sign In with PIN'), findsOneWidget);

    // Verify both Sign In with PIN and Sign Up with Google fit without overflow
    expect(find.text('Sign Up with Google'), findsOneWidget);
    expect(find.text('Sign In with PIN'), findsOneWidget);
    expect(find.text('First time here? Register with Gmail & PIN'), findsNothing);
  });

  testWidgets('CreatePinDialog renders smoothly on mobile viewport and scrolls without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: CelestialTheme.themeData,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  CreatePinDialog.show(ctx, email: 'mobile.test@gmail.com');
                },
                child: const Text('Open PIN Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open PIN Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Create Station PIN'), findsOneWidget);
    expect(find.text('Set Up Later'), findsOneWidget);
  });

  test('AuthService custom trial 0 days immediately expires station trial', () async {
    final admin = AppUser(
      uid: 'admin_test_1',
      email: 'adminpogi6@gmail.com',
      displayName: 'Admin User',
      isAdmin: true,
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now(),
    );
    final auth = AuthService(initialUser: admin);

    // Add cashier station
    await auth.addManagedAccount(
      email: 'station@celestialcafe.com',
      displayName: 'Station User',
      tier: SubscriptionTier.trial,
    );
    final stationUser = auth.managedAccounts.firstWhere((a) => a.email == 'station@celestialcafe.com');
    expect(stationUser.isTrialExpired, false);

    // Admin sets trial to 0 days
    await auth.updateAccountCustomTrial(stationUser.uid, 0);

    final updated = auth.managedAccounts.firstWhere((a) => a.uid == stationUser.uid);
    expect(updated.hasCustomTrial, true);
    expect(updated.customTrialDays, 0);
    expect(updated.trialDaysRemaining, 0);
    expect(updated.isTrialExpired, true);
  });

  testWidgets('TrialExpiredDialog renders developer contact details and license action', (WidgetTester tester) async {
    final expiredUser = AppUser(
      uid: 'station_user_expired',
      email: 'expired@celestialcafe.com',
      displayName: 'Station Expired',
      tier: SubscriptionTier.trial,
      hasCustomTrial: true,
      customTrialDays: 0,
      trialStartDate: DateTime.now(),
    );
    final auth = AuthService(initialUser: expiredUser);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: MaterialApp(
          theme: CelestialTheme.themeData,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => TrialExpiredDialog.show(ctx),
                  child: const Text('Show Expired Dialog'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Trigger dialog
    await tester.tap(find.text('Show Expired Dialog'));
    await tester.pumpAndSettle();

    // Verify Title and 0 Days Remaining Badge
    expect(find.text('Free Trial Has Concluded'), findsOneWidget);
    expect(find.textContaining('0 Days Remaining'), findsOneWidget);

    // Verify Developer Contact Information
    expect(find.text('Contact Developer for License Activation'), findsOneWidget);
    expect(find.text('Developer: JC Celestial'), findsOneWidget);
    expect(find.text('jccelestial04@gmail.com'), findsOneWidget);
    expect(find.text('Email Developer to Unlock'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Refresh License'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);

    // Dismiss dialog via Sign Out
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
  });

  testWidgets('MainWorkstationScaffold automatically opens TrialExpiredDialog when trial is 0 days', (WidgetTester tester) async {
    final expiredUser = AppUser(
      uid: 'auto_popup_user',
      email: 'autopopup@celestialcafe.com',
      displayName: 'Expired Cashier',
      tier: SubscriptionTier.trial,
      hasCustomTrial: true,
      customTrialDays: 0,
      trialStartDate: DateTime.now(),
    );
    final authService = AuthService(initialUser: expiredUser);

    await tester.pumpWidget(CelestialCafePosApp(authService: authService));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Dialog should be displayed immediately on station entry
    expect(find.text('Free Trial Has Concluded'), findsOneWidget);
    expect(find.textContaining('0 Days Remaining'), findsOneWidget);
    expect(find.text('Developer: JC Celestial'), findsOneWidget);

    // Clean up
    await tester.tap(find.text('Sign Out').last);
    await tester.pumpAndSettle();
  });

  testWidgets('CartPanel blocks checkout when station trial is expired and opens TrialExpiredDialog', (WidgetTester tester) async {
    final expiredUser = AppUser(
      uid: 'blocked_cart_user',
      email: 'blocked@celestialcafe.com',
      displayName: 'Blocked Cashier',
      tier: SubscriptionTier.trial,
      hasCustomTrial: true,
      customTrialDays: 0,
      trialStartDate: DateTime.now(),
    );
    final auth = AuthService(initialUser: expiredUser);
    final pos = PosProvider();

    // Add item to cart
    pos.addToCart(pos.menuItems.first);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthService>.value(value: auth),
          ChangeNotifierProvider<PosProvider>.value(value: pos),
        ],
        child: MaterialApp(
          navigatorKey: TopNotification.navigatorKey,
          theme: CelestialTheme.themeData,
          home: const Scaffold(
            body: SizedBox(
              width: 400,
              height: 700,
              child: CartPanel(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find Charge button
    final chargeButton = find.textContaining('Charge •');
    expect(chargeButton, findsOneWidget);

    // Tap Charge
    await tester.tap(chargeButton);
    await tester.pumpAndSettle();

    // Verify checkout was blocked and TrialExpiredDialog popped up
    expect(find.text('Free Trial Has Concluded'), findsOneWidget);
    expect(find.text('Contact Developer for License Activation'), findsOneWidget);

    // Clean up
    await tester.tap(find.text('Sign Out'));
    await tester.pumpAndSettle();
  });

  test('AuthService station email defaults only to accounts with registered PIN and starts clean', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.init();

    // On fresh install with no registered PINs, lastStationEmail is null
    expect(auth.lastStationEmail, isNull);

    // Register an account with PIN
    await auth.setPinForUser(email: 'barista.station@gmail.com', pin: '9876');
    expect(auth.hasPin('barista.station@gmail.com'), true);
    expect(auth.lastStationEmail, 'barista.station@gmail.com');

    // Verify sign in with registered PIN works directly
    await auth.signOut();
    final success = await auth.signInWithPin(email: 'barista.station@gmail.com', pin: '9876');
    expect(success, true);
    expect(auth.isLoggedIn, true);
    expect(auth.currentUser?.email, 'barista.station@gmail.com');
  });

  testWidgets('LoginScreen renders loading card with status and Cancel button during Google sign-in and cancels cleanly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify initial state renders Google sign up button
    expect(find.text('Sign In with Google'), findsNothing);
    expect(find.text('Sign Up with Google'), findsOneWidget);
    expect(find.text('Cancel Sign-In'), findsNothing);

    // Simulate Google sign-in starting and waiting for browser
    auth.setLoadingForTesting(true, statusMessage: 'Waiting for Google account selection in browser...');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Verify loading card with status and Cancel button appears
    expect(find.text('Waiting for Google account selection in browser...'), findsOneWidget);
    expect(find.text('Please complete sign-in in the browser, or tap Cancel below.'), findsOneWidget);
    expect(find.text('Cancel Sign-In'), findsOneWidget);
    expect(find.text('Sign In with Google'), findsNothing);
    expect(find.text('Sign Up with Google'), findsNothing);

    // Tap Cancel Sign-In
    await tester.tap(find.text('Cancel Sign-In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify loading state is cancelled, and Google button is restored
    expect(auth.isLoading, false);
    expect(auth.authStatusMessage, isNull);
    expect(find.text('Sign In with Google'), findsNothing);
    expect(find.text('Sign Up with Google'), findsOneWidget);
    expect(find.text('Cancel Sign-In'), findsNothing);
  });

  testWidgets('LoginScreen displays Recent Login with Google badge and displayName for remembered Google account', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'celestial_last_station_email': 'jccelestial04@gmail.com',
      'celestial_last_station_name': 'JC Celestial',
      'celestial_last_station_is_google': true,
      'celestial_auth_pin_credentials': '{"jccelestial04@gmail.com":"amNjZWxlc3RpYWwwNEBnbWFpbC5jb206MTIzNA=="}',
    });

    final auth = AuthService();
    auth.setStationEmailForTesting(
      'jccelestial04@gmail.com',
      displayName: 'JC Celestial',
      isGoogle: true,
    );

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify "Recent Login" badge and details
    expect(find.text('Recent Login'), findsOneWidget);
    expect(find.text('JC Celestial'), findsOneWidget);
    expect(find.text('jccelestial04@gmail.com'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Registered 4-Digit PIN'), findsOneWidget);
    expect(find.text('Sign In to Station'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);

    // Tapping the Recent Login card prompts for PIN input
    await tester.tap(find.text('JC Celestial'));
    await tester.pump();
    expect(find.text('Registered 4-Digit PIN'), findsOneWidget);

    // Tapping Remove clears the recent station account and leaves email and PIN fields ready
    await tester.tap(find.text('Remove'));
    await tester.pump();
    expect(find.text('Recent Login'), findsNothing);
    expect(find.text('Gmail Address / Email'), findsOneWidget);
    expect(find.text('4-Digit PIN'), findsOneWidget);
  });

  testWidgets('AuthService starts and stops cloud license sync timer on customer login and logout', (WidgetTester tester) async {
    final auth = AuthService();
    final customer = AppUser(
      uid: 'customer_1',
      email: 'customer@celestialcafe.com',
      displayName: 'Cafe Customer',
      tier: SubscriptionTier.trial,
      trialStartDate: DateTime.now(),
      isAdmin: false,
    );

    auth.setLoggedInUserForTesting(customer);
    auth.startCloudLicenseSyncTimer(forceInTest: true);

    // Verify user is logged in as non-admin customer
    expect(auth.currentUser?.email, 'customer@celestialcafe.com');
    expect(auth.currentUser?.isAdmin, false);

    // Stop timer on sign out
    await auth.signOut();
    expect(auth.currentUser, isNull);
  });

  testWidgets('When recent login is removed, entering a registered email prompts for 4-digit PIN before app access', (WidgetTester tester) async {
    final auth = AuthService();
    auth.registerPinForTesting('admin@celestialcafe.com', '1234');
    auth.setStationEmailForTesting(
      'admin@celestialcafe.com',
      displayName: 'Admin User',
      isGoogle: true,
    );

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Initially shows Recent Login card
    expect(find.text('Recent Login'), findsOneWidget);
    expect(find.text('admin@celestialcafe.com'), findsOneWidget);

    // Tap Remove
    await tester.tap(find.text('Remove'));
    await tester.pump();

    // Recent login card is removed
    expect(find.text('Recent Login'), findsNothing);

    // Enter registered email
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'admin@celestialcafe.com');
    await tester.pump();

    // Verify Registered Account badge and notice prompt
    expect(find.text('● Registered Account'), findsOneWidget);
    expect(find.text('Account registered. Please enter your 4-digit PIN below to access app.'), findsOneWidget);
    expect(find.text('Registered 4-Digit PIN'), findsOneWidget);
    expect(find.text('Sign In to Station'), findsOneWidget);
  });

  testWidgets('New Google user PIN creation returns to sign in, saves to recent, and requires PIN entry before app access', (WidgetTester tester) async {
    final auth = AuthService();
    // Simulate new user creating PIN with autoSignIn: false
    final success = await auth.setPinForUser(
      email: 'newbarista@gmail.com',
      pin: '9876',
      autoSignIn: false,
    );
    expect(success, true);
    expect(auth.currentUser, isNull);
    expect(auth.lastStationEmail, 'newbarista@gmail.com');

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Back to sign in screen, user sees Recent Login with their Gmail
    expect(find.text('Recent Login'), findsOneWidget);
    expect(find.text('newbarista@gmail.com'), findsOneWidget);

    // Tapping the card focuses PIN and prompts user
    await tester.tap(find.text('newbarista@gmail.com'));
    await tester.pump();
    expect(find.text('Registered 4-Digit PIN'), findsOneWidget);

    // User must enter their created PIN before continuing
    final pinField = find.byType(TextField).last;
    await tester.enterText(pinField, '9876');
    await tester.pump();
    await tester.tap(find.text('Sign In to Station'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // App signs in successfully and transitions to MainWorkstationScaffold
    expect(auth.currentUser?.email, 'newbarista@gmail.com');

    await auth.signOut();
  });

  testWidgets('LoginScreen renders Sign Up with Google button and both Email and PIN input fields', (WidgetTester tester) async {
    final auth = AuthService();
    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Sign In with Google is removed and Sign Up with Google is present
    expect(find.text('Sign In with Google'), findsNothing);
    expect(find.text('Sign Up with Google'), findsOneWidget);

    // Verify divider with Google sign up
    expect(find.text('OR SIGN UP WITH GOOGLE'), findsOneWidget);

    // Verify both Email and PIN input fields are rendered directly
    expect(find.text('Gmail Address / Email'), findsOneWidget);
    expect(find.text('4-Digit PIN'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));

    // Email field is editable
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'barista@gmail.com');
    await tester.pump();
    expect(find.text('barista@gmail.com'), findsOneWidget);

    // PIN field is editable
    final pinField = find.byType(TextField).last;
    await tester.enterText(pinField, '123');
    await tester.pump();
    expect(find.text('Sign In with PIN'), findsOneWidget);
  });

  testWidgets('First time here text link is removed from LoginScreen', (WidgetTester tester) async {
    final auth = AuthService();
    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify First time here link is completely removed
    expect(find.text('First time here? Register with Gmail & PIN'), findsNothing);
  });

  testWidgets('Attempting to register an already registered email redirects to PIN entry prompt', (WidgetTester tester) async {
    final auth = AuthService();
    auth.registerPinForTesting('barista.cafe@gmail.com', '5555');

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Enter registered email in main login
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'barista.cafe@gmail.com');
    await tester.pump();

    expect(find.text('Account registered. Please enter your 4-digit PIN below to access app.'), findsOneWidget);
    expect(find.text('Sign In to Station'), findsOneWidget);

    // Enter wrong PIN
    final pinField = find.byType(TextField).last;
    await tester.enterText(pinField, '9999');
    await tester.pump();
    await tester.tap(find.text('Sign In to Station'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify it does NOT offer to register a new station, but indicates Incorrect PIN
    expect(find.text('Register New Station?'), findsNothing);
    expect(find.text('Incorrect PIN. Please try again.'), findsOneWidget);

    // Enter correct PIN to continue
    await tester.enterText(pinField, '5555');
    await tester.pump();
    await tester.tap(find.text('Sign In to Station'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.currentUser?.email, 'barista.cafe@gmail.com');
    await auth.signOut();
  });

  testWidgets('Sign Up with Google with an already registered account populates email input field on main login without popups', (WidgetTester tester) async {
    final mockAuth = _MockGoogleSignUpAuthService('registered.barista@gmail.com');
    mockAuth.registerPinForTesting('registered.barista@gmail.com', '7777');

    await tester.pumpWidget(CelestialCafePosApp(authService: mockAuth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Tap "Sign Up with Google"
    final googleSignUpBtn = find.text('Sign Up with Google');
    expect(googleSignUpBtn, findsOneWidget);
    await tester.tap(googleSignUpBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify absolutely NO modal popups appeared (neither Google station quick access nor PIN creation)
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Google Station Sign In / Sign Up'), findsNothing);
    expect(find.text('Instant Station Access • POS Terminal'), findsNothing);
    expect(find.text('Register Station PIN'), findsNothing);

    // Verify app remains on main login screen with Gmail address filled out on the email TextField
    expect(find.text('registered.barista@gmail.com'), findsOneWidget);
    expect(find.text('Registered Gmail Address'), findsOneWidget);
    expect(find.text('● Registered Account'), findsOneWidget);

    // Verify feedback message notifies user to enter PIN
    expect(
      find.text('Account already registered! Please enter your 4-digit PIN below to continue.'),
      findsOneWidget,
    );

    // Enter registered PIN in the main login PIN field to complete sign in
    final pinField = find.byType(TextField).last;
    await tester.enterText(pinField, '7777');
    await tester.pump();

    final signInBtn = find.text('Sign In to Station');
    expect(signInBtn, findsOneWidget);
    await tester.tap(signInBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Signs in smoothly into app upon 4-digit PIN entry
    expect(mockAuth.currentUser?.email, 'registered.barista@gmail.com');
    await mockAuth.signOut();
  });

  testWidgets('Entering 4-digit PIN does not auto-verify until user clicks Sign In button', (WidgetTester tester) async {
    final auth = AuthService();
    auth.registerPinForTesting('barista.cafe@gmail.com', '1234');

    await tester.pumpWidget(CelestialCafePosApp(authService: auth));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Enter email and 4-digit PIN
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'barista.cafe@gmail.com');
    await tester.pump();

    final pinField = find.byType(TextField).last;
    await tester.enterText(pinField, '1234');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Confirm user is NOT automatically signed in
    expect(auth.currentUser, isNull);
    expect(find.text('Sign In to Station'), findsOneWidget);

    // User must click the button before continuing
    await tester.tap(find.text('Sign In to Station'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(auth.currentUser?.email, 'barista.cafe@gmail.com');
    await auth.signOut();
  });
}

class _MockGoogleSignUpAuthService extends AuthService {
  final String mockEmail;
  _MockGoogleSignUpAuthService(this.mockEmail);

  @override
  Future<GoogleAuthResult> signInWithGoogle({SubscriptionTier initialTier = SubscriptionTier.trial}) async {
    setPendingGoogleUserForTesting(
      AppUser(
        uid: 'google_registered_user_1',
        email: mockEmail,
        displayName: 'Registered Barista',
        trialStartDate: DateTime.now(),
      ),
    );
    return GoogleAuthResult.needsPin;
  }
}





