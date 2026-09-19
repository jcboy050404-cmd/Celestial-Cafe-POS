import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/app_feature.dart';
import 'package:celestial_pos/models/order.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/services/auth_service.dart';
import 'package:celestial_pos/screens/orders_history_screen.dart';
import 'package:celestial_pos/screens/inventory_screen.dart';
import 'package:celestial_pos/screens/login_screen.dart';
import 'package:celestial_pos/screens/online_orders_screen.dart';
import 'package:celestial_pos/widgets/online_ordering_dialog.dart';
import 'package:celestial_pos/main.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Multi-Owner and 3-Tier Role Architecture', () {
    test('Owner A and Owner B create separate cashiers with strict isolation', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();

      // Setup Owner A (Pro)
      final ownerA = AppUser(
        uid: 'owner_a_uid',
        email: 'ownerA@cafe.com',
        displayName: 'Owner A',
        tier: SubscriptionTier.pro,
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );
      // Setup Owner B (Pro)
      final ownerB = AppUser(
        uid: 'owner_b_uid',
        email: 'ownerB@cafe.com',
        displayName: 'Owner B',
        tier: SubscriptionTier.pro,
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );

      // 1. Owner A logs in and creates Cashier A1
      auth.setLoggedInUserForTesting(ownerA);
      final createdA1 = await auth.createCashierAccount(
        email: 'cashierA1@cafe.com',
        displayName: 'Counter 1',
        pin: '1234',
      );
      expect(createdA1, isTrue);

      // 2. Owner B logs in and creates Cashier B1
      auth.setLoggedInUserForTesting(ownerB);
      final createdB1 = await auth.createCashierAccount(
        email: 'cashierB1@cafe.com',
        displayName: 'Counter 2',
        pin: '5678',
      );
      expect(createdB1, isTrue);

      // 3. Verify Multi-Tenant Isolation
      // Owner A should only see Cashier A1
      final cashiersForA = auth.getCashiersForOwner('ownerA@cafe.com');
      expect(cashiersForA.length, 1);
      expect(cashiersForA.first.email, 'cashiera1@cafe.com');
      expect(cashiersForA.first.role, UserRole.cashier);
      expect(cashiersForA.first.ownerEmail, 'ownera@cafe.com');
      expect(cashiersForA.first.isCashier, isTrue);
      expect(cashiersForA.first.isOwner, isFalse);

      // Owner B should only see Cashier B1
      final cashiersForB = auth.getCashiersForOwner('ownerB@cafe.com');
      expect(cashiersForB.length, 1);
      expect(cashiersForB.first.email, 'cashierb1@cafe.com');
      expect(cashiersForB.first.role, UserRole.cashier);
      expect(cashiersForB.first.ownerEmail, 'ownerb@cafe.com');

      // Owner A cannot see Cashier B1
      expect(cashiersForA.any((c) => c.email == 'cashierb1@cafe.com'), isFalse);
      // Owner B cannot see Cashier A1
      expect(cashiersForB.any((c) => c.email == 'cashiera1@cafe.com'), isFalse);

      // 4. Cashier A1 logs in with PIN 1234
      await auth.signOut();
      final loginA1Success = await auth.signInWithPin(email: 'cashierA1@cafe.com', pin: '1234');
      expect(loginA1Success, isTrue);
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser!.email, 'cashiera1@cafe.com');
      expect(auth.currentUser!.isCashier, isTrue);
      expect(auth.currentUser!.ownerEmail, 'ownera@cafe.com');

      // Cashier cannot create other cashiers
      final rogueCreate = await auth.createCashierAccount(
        email: 'rogue@cafe.com',
        displayName: 'Unauthorized',
        pin: '9999',
      );
      expect(rogueCreate, isFalse);

      // 5. Owner A updates Cashier A1 PIN to 4321
      auth.setLoggedInUserForTesting(ownerA);
      final updateSuccess = await auth.updateCashierPin(email: 'cashiera1@cafe.com', newPin: '4321');
      expect(updateSuccess, isTrue);

      // Owner B cannot update Cashier A1 PIN (Cross-tenant security)
      auth.setLoggedInUserForTesting(ownerB);
      final crossUpdate = await auth.updateCashierPin(email: 'cashiera1@cafe.com', newPin: '0000');
      expect(crossUpdate, isFalse);

      // Cashier A1 logs in with new PIN 4321
      await auth.signOut();
      final loginNewPin = await auth.signInWithPin(email: 'cashiera1@cafe.com', pin: '4321');
      expect(loginNewPin, isTrue);

      // 6. Owner A deletes Cashier A1
      auth.setLoggedInUserForTesting(ownerA);
      final deleteSuccess = await auth.deleteCashierAccount('cashiera1@cafe.com');
      expect(deleteSuccess, isTrue);

      final cashiersAfterDelete = auth.getCashiersForOwner('ownerA@cafe.com');
      expect(cashiersAfterDelete.isEmpty, isTrue);

      // Cashier A1 can no longer sign in
      await auth.signOut();
      final failedLogin = await auth.signInWithPin(email: 'cashiera1@cafe.com', pin: '4321');
      expect(failedLogin, isFalse);
    });

    test('3-Tier Role Separation: Admin, Owner, Cashier', () {
      final adminUser = AppUser(
        uid: 'admin1',
        email: 'developer@jcpos.com',
        displayName: 'Developer Admin',
        trialStartDate: DateTime.now(),
        isAdmin: true,
      );
      final ownerUser = AppUser(
        uid: 'owner1',
        email: 'cafeowner@gmail.com',
        displayName: 'Store Owner',
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );
      final cashierUser = AppUser(
        uid: 'cashier1',
        email: 'cashier@cafe.com',
        displayName: 'Cashier 1',
        trialStartDate: DateTime.now(),
        role: UserRole.cashier,
        ownerEmail: 'cafeowner@gmail.com',
      );

      // Admin checks
      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.isOwner, isTrue); // Admin has owner powers
      expect(adminUser.isCashier, isFalse);

      // Owner checks
      expect(ownerUser.isAdmin, isFalse);
      expect(ownerUser.isOwner, isTrue);
      expect(ownerUser.isCashier, isFalse);

      // Cashier checks
      expect(cashierUser.isAdmin, isFalse);
      expect(cashierUser.isOwner, isFalse);
      expect(cashierUser.isCashier, isTrue);
      expect(cashierUser.ownerEmail, 'cafeowner@gmail.com');
    });
  });

  group('Cashier UI Restrictions', () {
    testWidgets('Cashier cannot clear order history or delete orders in OrdersHistoryScreen', (tester) async {
      final cashierUser = AppUser(
        uid: 'cashier_user_1',
        email: 'cashier@cafe.com',
        displayName: 'Cashier Staff',
        trialStartDate: DateTime.now(),
        role: UserRole.cashier,
        ownerEmail: 'owner@cafe.com',
      );
      final authService = AuthService(initialUser: cashierUser);
      final posProvider = PosProvider();

      // Create an order via cart checkout
      final item = posProvider.menuItems.first;
      posProvider.addToCart(item);
      posProvider.completeCheckout(paymentMethod: PaymentMethod.cash, amountTendered: 500);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
          ],
          child: const MaterialApp(
            home: OrdersHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Clear History" button is hidden for Cashier
      expect(find.text('Clear History'), findsNothing);
      // Verify "Reset Counter" button is hidden for Cashier
      expect(find.text('Reset Counter'), findsNothing);
      // Verify order deletion trash icon is hidden for Cashier
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('Owner can view clear history and delete buttons in OrdersHistoryScreen', (tester) async {
      final ownerUser = AppUser(
        uid: 'owner_user_1',
        email: 'owner@cafe.com',
        displayName: 'Store Owner',
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );
      final authService = AuthService(initialUser: ownerUser);
      final posProvider = PosProvider();

      final item = posProvider.menuItems.first;
      posProvider.addToCart(item);
      posProvider.completeCheckout(paymentMethod: PaymentMethod.cash, amountTendered: 500);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
          ],
          child: const MaterialApp(
            home: OrdersHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Owner sees "Clear History"
      expect(find.text('Clear History'), findsOneWidget);
      // Owner sees delete order icon
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('Cashier in InventoryScreen sees Read-Only mode without Add or Price Settings', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cashierUser = AppUser(
        uid: 'cashier_user_2',
        email: 'cashier2@cafe.com',
        displayName: 'Cashier Two',
        trialStartDate: DateTime.now(),
        role: UserRole.cashier,
        ownerEmail: 'owner@cafe.com',
      );
      final authService = AuthService(initialUser: cashierUser);
      final posProvider = PosProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
          ],
          child: const MaterialApp(
            home: InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cashier view badge is displayed
      expect(find.text('Cashier View (Read Only)'), findsOneWidget);
      // "Add Item" button is hidden
      expect(find.text('Add Item'), findsNothing);
      // "Price Settings" button is hidden
      expect(find.text('Price Settings'), findsNothing);
      // Edit and Delete icons for items are hidden
      expect(find.byIcon(Icons.edit_note_rounded), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('Cashier in InventoryScreen mobile layout also shows Read-Only mode', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 740 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final cashierUser = AppUser(
        uid: 'cashier_user_mobile',
        email: 'cashier_mobile@cafe.com',
        displayName: 'Mobile Cashier',
        trialStartDate: DateTime.now(),
        role: UserRole.cashier,
        ownerEmail: 'owner@cafe.com',
      );
      final authService = AuthService(initialUser: cashierUser);
      final posProvider = PosProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
          ],
          child: const MaterialApp(
            home: InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cashier View (Read Only)'), findsOneWidget);
      expect(find.text('Add'), findsNothing);
      expect(find.text('Prices'), findsNothing);
      expect(find.text('Edit'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    test('Cashier account creation with station label and strict access enforcement', () async {
      final owner = AppUser(
        uid: 'owner_test',
        email: 'owner@celestial.com',
        displayName: 'Owner',
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );
      final auth = AuthService(initialUser: owner);

      final created = await auth.createCashierAccount(
        email: 'cashier1@celestial.com',
        displayName: 'Counter 1',
        pin: '1111',
        role: UserRole.cashier,
        customRoleTitle: 'CASHIER 1',
      );
      expect(created, isTrue);

      final cashiers = auth.getCashiersForCurrentOwner();
      expect(cashiers.length, 1);
      final cashier = cashiers.first;
      expect(cashier.roleBadgeLabel, 'CASHIER 1');
      expect(cashier.isCashier, isTrue);

      // Cashier only accesses POS, Order History, and Online Orders
      expect(cashier.isFeatureEnabled(AppFeature.orderHistory), isTrue);
      expect(cashier.isFeatureEnabled(AppFeature.inventory), isFalse);
      expect(cashier.isFeatureEnabled(AppFeature.analytics), isFalse);
      expect(cashier.isFeatureEnabled(AppFeature.foodCosting), isFalse);
      expect(cashier.isFeatureEnabled(AppFeature.storeSettings), isFalse);

      // Updating role & label
      final updated = await auth.updateCashierRole(
        email: 'cashier1@celestial.com',
        newRole: UserRole.cashier,
        customRoleTitle: 'DRIVE-THRU',
      );
      expect(updated, isTrue);
      final updatedCashier = auth.getCashiersForCurrentOwner().first;
      expect(updatedCashier.roleBadgeLabel, 'DRIVE-THRU');
    });

    testWidgets('Cashier in MainWorkstationScaffold only sees POS, Online Orders, and Order History', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cashierUser = AppUser(
        uid: 'cashier_desk_1',
        email: 'cashier1@cafe.com',
        displayName: 'Station 1',
        trialStartDate: DateTime.now(),
        role: UserRole.cashier,
        customRoleTitle: 'CASHIER 1',
        ownerEmail: 'owner@cafe.com',
      );
      final authService = AuthService(initialUser: cashierUser);
      final posProvider = PosProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<PosProvider>.value(value: posProvider),
          ],
          child: const MaterialApp(
            home: MainWorkstationScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Allowed tabs
      expect(find.text('POS Station'), findsOneWidget);
      expect(find.text('Online Orders'), findsOneWidget);
      expect(find.text('Order History'), findsOneWidget);

      // Blocked tabs for cashier
      expect(find.text('Menu & Stock'), findsNothing);
      expect(find.text('Analytics'), findsNothing);
      expect(find.text('Food Costing'), findsNothing);

      // Store settings button is hidden for cashier
      expect(find.byTooltip('Store Settings & Station Configuration'), findsNothing);

      // Cashier role badge is visible in header
      expect(find.text('CASHIER 1'), findsWidgets);
    });

    test('Cashier Name and PIN Login: service layer resolves displayName, station label, and username to account', () async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();

      final owner = AppUser(
        uid: 'owner_test_uid',
        email: 'owner@test.com',
        displayName: 'Store Owner',
        tier: SubscriptionTier.pro,
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );
      auth.setLoggedInUserForTesting(owner);

      // Create cashier account with distinct Display Name, Station Label, and Username
      await auth.createCashierAccount(
        email: 'cashier_register1@cafe.com',
        pin: '5566',
        displayName: 'Maria Santos',
        customRoleTitle: 'COUNTER 1',
      );

      // 1. Login with Cashier Name ("Maria Santos") + PIN
      final loginByName = await auth.signInStaff(nameOrEmail: 'Maria Santos', pin: '5566');
      expect(loginByName, isTrue);
      expect(auth.currentUser?.email, equals('cashier_register1@cafe.com'));
      expect(auth.currentUser?.displayName, equals('Maria Santos'));
      expect(auth.currentUser?.roleBadgeLabel, equals('COUNTER 1'));

      // 2. Login with Station Label ("COUNTER 1") + PIN
      final loginByLabel = await auth.signInStaff(nameOrEmail: 'COUNTER 1', pin: '5566');
      expect(loginByLabel, isTrue);
      expect(auth.currentUser?.email, equals('cashier_register1@cafe.com'));

      // 3. Login with Username prefix ("cashier_register1") + PIN
      final loginByUsername = await auth.signInStaff(nameOrEmail: 'cashier_register1', pin: '5566');
      expect(loginByUsername, isTrue);
      expect(auth.currentUser?.email, equals('cashier_register1@cafe.com'));

      // 4. Incorrect PIN fails
      final wrongPin = await auth.signInStaff(nameOrEmail: 'Maria Santos', pin: '9999');
      expect(wrongPin, isFalse);

      // 5. Unknown Cashier Name fails
      final unknownStaff = await auth.signInStaff(nameOrEmail: 'Unknown Person', pin: '5566');
      expect(unknownStaff, isFalse);
    });

    testWidgets('Cashier Name and PIN Login: LoginScreen widget permits staff sign in using Cashier Name and PIN', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();
      final pos = PosProvider();

      final owner = AppUser(
        uid: 'owner_ui_uid',
        email: 'owner@ui.com',
        displayName: 'Store Owner',
        tier: SubscriptionTier.pro,
        trialStartDate: DateTime.now(),
        role: UserRole.owner,
      );
      auth.setLoggedInUserForTesting(owner);

      await auth.createCashierAccount(
        email: 'cashier_front@cafe.com',
        pin: '1234',
        displayName: 'Front Cashier',
        customRoleTitle: 'CASHIER 1',
      );

      // Log out so LoginScreen is presented
      await auth.signOut();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<PosProvider>.value(value: pos),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Employee (Staff) login tab
      final employeeTabFinder = find.byKey(const ValueKey('login_role_employee_tab'));
      expect(employeeTabFinder, findsOneWidget);
      await tester.tap(employeeTabFinder);
      await tester.pumpAndSettle();

      // Verify the Cashier Name / Email input field is present
      final emailInputFinder = find.byKey(const ValueKey('employee_email_input'));
      expect(emailInputFinder, findsOneWidget);

      // Enter Cashier Name ("Front Cashier") instead of email
      await tester.enterText(emailInputFinder, 'Front Cashier');
      await tester.pumpAndSettle();

      // Enter 4-digit PIN ("1234")
      final pinInputFinder = find.byType(TextField).last;
      await tester.enterText(pinInputFinder, '1234');
      await tester.pumpAndSettle();

      // Tap Sign In as Staff button
      final signInBtnFinder = find.byKey(const ValueKey('employee_sign_in_btn'));
      expect(signInBtnFinder, findsOneWidget);
      await tester.tap(signInBtnFinder);
      await tester.pumpAndSettle();

      // Verify user is successfully logged in as cashier
      expect(auth.currentUser, isNotNull);
      expect(auth.currentUser?.email, equals('cashier_front@cafe.com'));
      expect(auth.currentUser?.displayName, equals('Front Cashier'));
      expect(auth.currentUser?.isCashier, isTrue);
    });

    testWidgets('Cashier cannot access customer online ordering settings, order links, or store controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();
      final pos = PosProvider();

      final cashier = AppUser(
        uid: 'cashier_online_uid',
        email: 'cashier@cafe.com',
        displayName: 'Cashier Station',
        role: UserRole.cashier,
        tier: SubscriptionTier.trial,
        trialStartDate: DateTime.now(),
        customRoleTitle: 'CASHIER 1',
      );
      auth.setLoggedInUserForTesting(cashier);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: auth),
            ChangeNotifierProvider<PosProvider>.value(value: pos),
          ],
          child: const MaterialApp(
            home: MainWorkstationScaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. QR button is hidden in HeaderBar on Desktop
      expect(find.byKey(const ValueKey('desktop_online_order_btn')), findsNothing);

      // 2. Switch to Online Orders Tab
      await tester.tap(find.text('Online Orders'));
      await tester.pumpAndSettle();

      // 3. 'QR & Store Controls' button is hidden for cashier in OnlineOrdersScreen
      expect(find.text('QR & Store Controls'), findsNothing);

      // 4. In empty state, 'Show Ordering QR Code & Link' button is hidden for cashier
      expect(find.text('Show Ordering QR Code & Link'), findsNothing);

      // 5. Calling OnlineOrderingDialog.show does not open configuration dialog
      await OnlineOrderingDialog.show(tester.element(find.byType(OnlineOrdersScreen)));
      await tester.pumpAndSettle();
      expect(find.text('Online Store Controls'), findsNothing);
    });
  });
}
