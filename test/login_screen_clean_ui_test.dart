import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/main.dart';
import 'package:celestial_pos/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen Clean Layout Tests', () {
    testWidgets('LoginScreen does not contain the coffee/milktea/cheesecake tagline', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = AuthService();

      await tester.pumpWidget(CelestialCafePosApp(authService: auth));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify tagline is removed
      expect(find.text('COFFEE • MILKTEA • CHEESECAKE • BITES'), findsNothing);
      expect(find.textContaining(RegExp(r'milktea', caseSensitive: false)), findsNothing);
      expect(find.textContaining(RegExp(r'cheesecake', caseSensitive: false)), findsNothing);
    });

    testWidgets('LoginScreen displays clean Recent Login card with displayName, email, Switch and Remove', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'celestial_last_station_email': 'jccelestial04@gmail.com',
        'celestial_last_station_name': 'Jc Celestial',
        'celestial_last_station_is_google': true,
        'celestial_auth_pin_credentials': '{"jccelestial04@gmail.com":"amNjZWxlc3RpYWwwNEBnbWFpbC5jb206MTIzNA=="}',
      });

      final auth = AuthService();
      auth.setStationEmailForTesting(
        'jccelestial04@gmail.com',
        displayName: 'Jc Celestial',
        isGoogle: true,
      );

      await tester.pumpWidget(CelestialCafePosApp(authService: auth));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Header label
      expect(find.text('Recent Login'), findsOneWidget);

      // Card content
      expect(find.text('Jc Celestial'), findsOneWidget);
      expect(find.text('jccelestial04@gmail.com'), findsOneWidget);
      expect(find.text('Switch'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);

      // Verify redundant subtitle 'Station Gmail Account' is NOT displayed when displayName is present
      expect(find.text('Station Gmail Account'), findsNothing);

      // Verify PIN field is visible below
      expect(find.text('Registered 4-Digit PIN'), findsOneWidget);
      expect(find.text('Ready to Sign In'), findsOneWidget);
    });
  });
}
