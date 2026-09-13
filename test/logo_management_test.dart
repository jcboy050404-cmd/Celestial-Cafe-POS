import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:celestial_pos/providers/pos_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Logo Management Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('setting custom logo updates customLogoBytes and hasCustomLogo', () async {
      final provider = PosProvider();
      expect(provider.hasCustomLogo, isFalse);

      final dummyBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]); // PNG header
      await provider.setCustomLogo(dummyBytes);

      expect(provider.hasCustomLogo, isTrue);
      expect(provider.customLogoBytes, equals(dummyBytes));
      expect(provider.customLogoBase64, equals(base64Encode(dummyBytes)));
    });

    test('resetting to default logo clears customLogoBytes and hasCustomLogo', () async {
      final provider = PosProvider();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4]);
      await provider.setCustomLogo(dummyBytes);
      expect(provider.hasCustomLogo, isTrue);

      await provider.resetToDefaultLogo();
      expect(provider.hasCustomLogo, isFalse);
      expect(provider.customLogoBytes, isNull);
      expect(provider.customLogoBase64, isNull);
    });
  });
}
