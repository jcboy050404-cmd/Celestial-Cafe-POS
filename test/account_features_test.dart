import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/models/app_feature.dart';
import 'package:celestial_pos/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppUser feature permission tests', () {
    test('regular user with no restrictions has all features enabled', () {
      final user = AppUser(
        uid: 'user_1',
        email: 'cashier@cafe.com',
        displayName: 'Cashier 1',
        trialStartDate: DateTime.now(),
        isAdmin: false,
      );

      expect(user.isFeatureEnabled(AppFeature.foodCosting), isTrue);
      expect(user.isFeatureEnabled(AppFeature.analytics), isTrue);
      expect(user.isFeatureEnabled(AppFeature.inventory), isTrue);
      expect(user.isFeatureEnabled(AppFeature.orderHistory), isTrue);
      expect(user.isFeatureEnabled(AppFeature.storeSettings), isTrue);
    });

    test('regular user with disabled food_costing has it disabled', () {
      final user = AppUser(
        uid: 'user_2',
        email: 'station2@gmail.com',
        displayName: 'Station 2',
        trialStartDate: DateTime.now(),
        isAdmin: false,
        disabledFeatures: [AppFeature.foodCosting],
      );

      expect(user.isFeatureEnabled(AppFeature.foodCosting), isFalse);
      expect(user.isFeatureEnabled(AppFeature.analytics), isTrue);
      expect(user.isFeatureEnabled(AppFeature.inventory), isTrue);
    });

    test('admin account ALWAYS has all features enabled even if in disabledFeatures list', () {
      final admin = AppUser(
        uid: 'admin_1',
        email: 'adminpogi6@gmail.com',
        displayName: 'Store Admin',
        trialStartDate: DateTime.now(),
        isAdmin: true,
        disabledFeatures: [
          AppFeature.foodCosting,
          AppFeature.analytics,
          AppFeature.inventory,
          AppFeature.orderHistory,
          AppFeature.storeSettings,
        ],
      );

      expect(admin.isFeatureEnabled(AppFeature.foodCosting), isTrue);
      expect(admin.isFeatureEnabled(AppFeature.analytics), isTrue);
      expect(admin.isFeatureEnabled(AppFeature.inventory), isTrue);
      expect(admin.isFeatureEnabled(AppFeature.orderHistory), isTrue);
      expect(admin.isFeatureEnabled(AppFeature.storeSettings), isTrue);
    });

    test('toJson and fromJson preserves disabledFeatures list', () {
      final original = AppUser(
        uid: 'user_3',
        email: 'station3@gmail.com',
        displayName: 'Station 3',
        trialStartDate: DateTime.now(),
        isAdmin: false,
        disabledFeatures: [AppFeature.foodCosting, AppFeature.analytics],
      );

      final json = original.toJson();
      final restored = AppUser.fromJson(json);

      expect(restored.disabledFeatures, contains(AppFeature.foodCosting));
      expect(restored.disabledFeatures, contains(AppFeature.analytics));
      expect(restored.isFeatureEnabled(AppFeature.foodCosting), isFalse);
      expect(restored.isFeatureEnabled(AppFeature.analytics), isFalse);
      expect(restored.isFeatureEnabled(AppFeature.inventory), isTrue);
    });

    test('copyWith updates disabledFeatures correctly', () {
      final user = AppUser(
        uid: 'user_4',
        email: 'station4@gmail.com',
        displayName: 'Station 4',
        trialStartDate: DateTime.now(),
        isAdmin: false,
      );

      expect(user.disabledFeatures, isEmpty);

      final updated = user.copyWith(disabledFeatures: [AppFeature.storeSettings]);
      expect(updated.disabledFeatures, equals([AppFeature.storeSettings]));
      expect(updated.isFeatureEnabled(AppFeature.storeSettings), isFalse);
    });
  });

  group('AuthService feature management tests', () {
    test('admin can update account disabled features and sync active session', () async {
      final adminUser = AppUser(
        uid: 'admin_master',
        email: 'adminpogi6@gmail.com',
        displayName: 'Master Admin',
        trialStartDate: DateTime.now(),
        isAdmin: true,
      );

      final stationUser = AppUser(
        uid: 'station_patio',
        email: 'patio@gmail.com',
        displayName: 'Patio Station',
        trialStartDate: DateTime.now(),
        isAdmin: false,
      );

      final auth = AuthService(initialUser: adminUser);
      // Add the station user to managed accounts
      await auth.addManagedAccount(
        email: stationUser.email,
        displayName: stationUser.displayName,
        tier: SubscriptionTier.trial,
      );

      // Now admin disables food_costing for patio station
      await auth.updateAccountDisabledFeatures(stationUser.email, [AppFeature.foodCosting]);

      final updatedPatio = auth.managedAccounts.firstWhere((a) => a.email == stationUser.email);
      expect(updatedPatio.isFeatureEnabled(AppFeature.foodCosting), isFalse);
      expect(updatedPatio.isFeatureEnabled(AppFeature.analytics), isTrue);
    });

    test('non-admin cannot update account disabled features', () async {
      final regularUser = AppUser(
        uid: 'cashier_1',
        email: 'cashier@gmail.com',
        displayName: 'Cashier',
        trialStartDate: DateTime.now(),
        isAdmin: false,
      );

      final auth = AuthService(initialUser: regularUser);
      await auth.updateAccountDisabledFeatures(regularUser.uid, [AppFeature.foodCosting]);

      // Regular user's features should not be modified
      expect(auth.isFeatureEnabled(AppFeature.foodCosting), isTrue);
    });
  });
}
