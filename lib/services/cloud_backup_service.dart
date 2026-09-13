import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';
import 'auth_service.dart';

/// Service responsible for managing Cloud Backup & Restore for PRO users.
///
/// Backs up:
/// - User Pro License & Identity
/// - Cafe Store Details (Name, Tagline, Address)
/// - Cafe Logo (Stored as Base64 and/or Firebase Cloud Storage)
///
/// When an app is cleared or reinstalled, signing in with the Pro account
/// automatically recovers this data from Firebase.
class CloudBackupService {
  static final CloudBackupService _instance = CloudBackupService._internal();
  factory CloudBackupService() => _instance;
  CloudBackupService._internal();

  static const String _rtdbUrl =
      'https://celestial-cafe-pos-2026-default-rtdb.asia-southeast1.firebasedatabase.app';

  static String get _storageBucket =>
      DefaultFirebaseOptions.currentPlatform.storageBucket ??
      'celestial-cafe-pos-2026.firebasestorage.app';

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String _sanitizeEmailKey(String email) {
    return email.trim().toLowerCase().replaceAll('.', ',');
  }

  /// Checks if internet connectivity is available
  Future<bool> _isOnline() async {
    if (kIsWeb) return true;
    try {
      final res = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Uploads logo to Firebase Storage REST API, returning download URL if available.
  Future<String?> _uploadLogoToStorage({
    required String emailKey,
    required Uint8List logoBytes,
  }) async {
    try {
      final objectName = Uri.encodeComponent('logos/${emailKey}_logo.png');
      final url = Uri.parse(
        'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o?uploadType=media&name=$objectName',
      );

      final res = await http.post(
        url,
        headers: {'Content-Type': 'image/png'},
        body: logoBytes,
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = json.decode(res.body);
        final downloadToken = data['downloadTokens'] ?? data['token'];
        if (downloadToken != null) {
          return 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$objectName?alt=media&token=$downloadToken';
        }
        return 'https://firebasestorage.googleapis.com/v0/b/$_storageBucket/o/$objectName?alt=media';
      }
    } catch (e) {
      debugPrint('CloudBackup: Firebase Storage upload fallback: $e');
    }
    return null;
  }

  /// Saves a complete Cloud Backup for a PRO user.
  /// Silently ignores non-Pro users to protect Pro exclusivity.
  Future<bool> backupProData({
    required AppUser user,
    required String storeName,
    required String storeTagline,
    required String storeAddress,
    Uint8List? logoBytes,
    String? logoBase64,
  }) async {
    // Pro-Only Security Guard
    if (!user.isPro && !user.isAdmin) {
      debugPrint('CloudBackup: Skipped. User ${user.email} is not PRO.');
      return false;
    }

    final cleanEmail = user.email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    _isSyncing = true;
    try {
      final online = await _isOnline();
      if (!online) {
        debugPrint('CloudBackup: Device is offline. Will sync when reconnected.');
        _isSyncing = false;
        return false;
      }

      final emailKey = _sanitizeEmailKey(cleanEmail);

      String? effectiveBase64 = logoBase64;
      if (effectiveBase64 == null && logoBytes != null && logoBytes.isNotEmpty) {
        effectiveBase64 = base64Encode(logoBytes);
      }

      // Upload image to Firebase Storage if logo bytes are present
      String? logoStorageUrl;
      if (logoBytes != null && logoBytes.isNotEmpty) {
        logoStorageUrl = await _uploadLogoToStorage(
          emailKey: emailKey,
          logoBytes: logoBytes,
        );
      }

      final backupPayload = <String, dynamic>{
        'uid': user.uid,
        'email': cleanEmail,
        'displayName': user.displayName,
        'tier': 'pro',
        'isAdmin': user.isAdmin,
        'proActivatedDate': user.proActivatedDate?.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'storeName': storeName,
        'storeTagline': storeTagline,
        'storeAddress': storeAddress,
        'logoUrl': logoStorageUrl,
        'hasCustomLogo': effectiveBase64 != null && effectiveBase64.isNotEmpty,
        'updatedAt': DateTime.now().toIso8601String(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      };

      // If logo is reasonably sized, store base64 as instant cloud fallback
      if (effectiveBase64 != null && effectiveBase64.length < 500000) {
        backupPayload['customLogoBase64'] = effectiveBase64;
      }

      final uri = Uri.parse('$_rtdbUrl/pro_backups/$emailKey.json');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(backupPayload),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        _lastSyncTime = DateTime.now();
        debugPrint('CloudBackup: Successfully saved Pro backup for $cleanEmail');
        return true;
      } else {
        debugPrint('CloudBackup: Failed with status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('CloudBackup exception: $e');
    } finally {
      _isSyncing = false;
    }
    return false;
  }

  /// Restores Pro backup data from Firebase for the specified email.
  Future<Map<String, dynamic>?> fetchProBackup(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      final emailKey = _sanitizeEmailKey(cleanEmail);
      final uri = Uri.parse('$_rtdbUrl/pro_backups/$emailKey.json');

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final data = json.decode(res.body);
        if (data is Map<String, dynamic>) {
          debugPrint('CloudBackup: Retrieved cloud backup for $cleanEmail');
          return data;
        }
      }
    } catch (e) {
      debugPrint('CloudBackup: Restore fetch error: $e');
    }
    return null;
  }
}
