import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/services/auth_service.dart';
import 'package:celestial_pos/widgets/header_bar.dart';

void main() {
  group('Account Role Label & Badge Tests', () {
    test('roleBadgeLabel returns correct labels for all roles', () {
      final now = DateTime.now();

      final owner = AppUser(
        uid: 'u_owner',
        email: 'jc@gmail.com',
        displayName: 'JC Celestial',
        role: UserRole.owner,
        trialStartDate: now,
      );
      expect(owner.roleBadgeLabel, 'OWNER');
      expect(owner.isOwner, isTrue);
      expect(owner.isCashier, isFalse);

      final admin = AppUser(
        uid: 'u_admin',
        email: 'admin@celestialcafe.com',
        displayName: 'Super Admin',
        isAdmin: true,
        trialStartDate: now,
      );
      expect(admin.roleBadgeLabel, 'ADMIN');
      expect(admin.isAdmin, isTrue);

      final cashier = AppUser(
        uid: 'u_cashier',
        email: 'counter@cafe.com',
        displayName: 'Main Counter',
        role: UserRole.cashier,
        trialStartDate: now,
      );
      expect(cashier.roleBadgeLabel, 'CASHIER');
      expect(cashier.isCashier, isTrue);

      final barista = AppUser(
        uid: 'u_barista',
        email: 'barista.station@cafe.com',
        displayName: 'Espresso Bar',
        role: UserRole.barista,
        trialStartDate: now,
      );
      expect(barista.roleBadgeLabel, 'BARISTA');
      expect(barista.isCashier, isTrue);
      expect(barista.isBarista, isTrue);

      final manager = AppUser(
        uid: 'u_mgr',
        email: 'manager@cafe.com',
        displayName: 'Floor Manager',
        role: UserRole.manager,
        trialStartDate: now,
      );
      expect(manager.roleBadgeLabel, 'MANAGER');
      expect(manager.isCashier, isTrue);

      final staff = AppUser(
        uid: 'u_staff',
        email: 'server@cafe.com',
        displayName: 'Dining Staff',
        role: UserRole.staff,
        trialStartDate: now,
      );
      expect(staff.roleBadgeLabel, 'STAFF');
      expect(staff.isCashier, isTrue);
    });

    test('Smart role inference from email or displayName', () {
      final now = DateTime.now();
      final inferredBarista = AppUser(
        uid: 'u_inf_barista',
        email: 'barista1@cafe.com',
        displayName: 'Station 1',
        role: UserRole.cashier,
        trialStartDate: now,
      );
      expect(inferredBarista.roleBadgeLabel, 'BARISTA');

      final inferredCashier = AppUser(
        uid: 'u_inf_cashier',
        email: 'cashier2@cafe.com',
        displayName: 'Register 2',
        role: UserRole.owner, // fallback
        trialStartDate: now,
      );
      expect(inferredCashier.roleBadgeLabel, 'CASHIER');
    });

    testWidgets('HeaderBar.buildRoleBadge renders role and icon correctly', (tester) async {
      final baristaUser = AppUser(
        uid: 'u_b',
        email: 'barista@cafe.com',
        displayName: 'Alex',
        role: UserRole.barista,
        trialStartDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeaderBar.buildRoleBadge(baristaUser),
          ),
        ),
      );

      expect(find.text('BARISTA'), findsOneWidget);
      expect(find.byIcon(Icons.coffee_rounded), findsOneWidget);
    });

    testWidgets('HeaderBar.buildRoleBadge renders Cashier badge correctly', (tester) async {
      final cashierUser = AppUser(
        uid: 'u_c',
        email: 'cashier@cafe.com',
        displayName: 'Sam',
        role: UserRole.cashier,
        trialStartDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeaderBar.buildRoleBadge(cashierUser),
          ),
        ),
      );

      expect(find.text('CASHIER'), findsOneWidget);
      expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    });

    testWidgets('HeaderBar.buildRoleBadge renders Owner badge correctly', (tester) async {
      final ownerUser = AppUser(
        uid: 'u_o',
        email: 'jc@gmail.com',
        displayName: 'JC Celestial',
        role: UserRole.owner,
        trialStartDate: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeaderBar.buildRoleBadge(ownerUser),
          ),
        ),
      );

      expect(find.text('OWNER'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsOneWidget);
    });
  });
}
