import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, HttpServer, InternetAddress, Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';

enum SubscriptionTier {
  trial('Trial', 'Free Trial License'),
  pro('Pro', 'Pro Enterprise License');

  final String label;
  final String description;
  const SubscriptionTier(this.label, this.description);
}

enum GoogleAuthResult {
  success,
  needsPin,
  needsQuickSetup,
  cancelled,
  error,
}

enum UserRole {
  admin,
  owner,
  cashier,
  barista,
  manager,
  staff;

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.owner:
        return 'OWNER';
      case UserRole.cashier:
        return 'CASHIER';
      case UserRole.barista:
        return 'BARISTA';
      case UserRole.manager:
        return 'MANAGER';
      case UserRole.staff:
        return 'STAFF';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.owner:
        return 'Store Owner';
      case UserRole.cashier:
        return 'Cashier';
      case UserRole.barista:
        return 'Barista';
      case UserRole.manager:
        return 'Manager';
      case UserRole.staff:
        return 'Staff';
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final SubscriptionTier tier;
  final DateTime trialStartDate;
  final DateTime? proActivatedDate;
  final bool isAdmin;
  final UserRole role;
  final String? customRoleTitle;
  final String? ownerEmail;
  final int customTrialDays;
  final bool hasCustomTrial;
  final String? idToken;
  final List<String> disabledFeatures;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.tier = SubscriptionTier.trial,
    required this.trialStartDate,
    this.proActivatedDate,
    this.isAdmin = false,
    UserRole? role,
    this.customRoleTitle,
    this.ownerEmail,
    this.customTrialDays = 14,
    this.hasCustomTrial = false,
    this.idToken,
    this.disabledFeatures = const [],
  }) : role = isAdmin ? UserRole.admin : (role ?? UserRole.owner);

  bool get isPro => tier == SubscriptionTier.pro;
  bool get isOwner => isAdmin || role == UserRole.owner;
  bool get isStaff => !isAdmin && role != UserRole.owner;
  bool get isCashier => !isAdmin && role != UserRole.owner;
  bool get isBarista => role == UserRole.barista || roleBadgeLabel == 'BARISTA';

  String get roleBadgeLabel {
    if (isAdmin) return 'ADMIN';
    if (customRoleTitle != null && customRoleTitle!.trim().isNotEmpty) {
      return customRoleTitle!.trim().toUpperCase();
    }
    final lowerEmail = email.toLowerCase();
    final lowerName = displayName.toLowerCase();
    if (role == UserRole.barista || lowerEmail.contains('barista') || lowerName.contains('barista')) {
      return 'BARISTA';
    }
    if (role == UserRole.manager || lowerEmail.contains('manager') || lowerName.contains('manager')) {
      return 'MANAGER';
    }
    if (role == UserRole.staff || lowerEmail.contains('staff') || lowerName.contains('staff')) {
      return 'STAFF';
    }
    if (role == UserRole.cashier || lowerEmail.contains('cashier') || lowerName.contains('cashier')) {
      return 'CASHIER';
    }
    if (role == UserRole.owner) {
      return 'OWNER';
    }
    return role.label;
  }

  bool isFeatureEnabled(String featureKey) {
    if (isAdmin) return true;
    if (isCashier) {
      // Cashier stations are strictly restricted to POS, Order History, and Online Orders only.
      // (POS and Online Orders are core workstations; Order History is the only allowed AppFeature).
      if (featureKey == 'order_history') {
        return !disabledFeatures.contains(featureKey);
      }
      return false;
    }
    return !disabledFeatures.contains(featureKey);
  }

  int effectiveTrialDays([int? fallbackDefault]) {
    if (hasCustomTrial) return customTrialDays;
    return fallbackDefault ?? (AuthService._instance?.defaultTrialDays ?? customTrialDays);
  }

  int get trialDaysRemaining {
    if (isPro) return 999;
    final total = effectiveTrialDays();
    if (total <= 0) return 0;
    final elapsed = DateTime.now().difference(trialStartDate).inDays;
    return (total - elapsed).clamp(0, total);
  }

  bool get isTrialExpired => !isPro && !isAdmin && trialDaysRemaining <= 0;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    SubscriptionTier? tier,
    DateTime? trialStartDate,
    DateTime? proActivatedDate,
    bool? isAdmin,
    UserRole? role,
    String? customRoleTitle,
    String? ownerEmail,
    int? customTrialDays,
    bool? hasCustomTrial,
    String? idToken,
    List<String>? disabledFeatures,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      tier: tier ?? this.tier,
      trialStartDate: trialStartDate ?? this.trialStartDate,
      proActivatedDate: proActivatedDate ?? this.proActivatedDate,
      isAdmin: isAdmin ?? this.isAdmin,
      role: role ?? this.role,
      customRoleTitle: customRoleTitle ?? this.customRoleTitle,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      customTrialDays: customTrialDays ?? this.customTrialDays,
      hasCustomTrial: hasCustomTrial ?? this.hasCustomTrial,
      idToken: idToken ?? this.idToken,
      disabledFeatures: disabledFeatures ?? this.disabledFeatures,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'tier': tier.name,
        'trialStartDate': trialStartDate.toIso8601String(),
        'proActivatedDate': proActivatedDate?.toIso8601String(),
        'isAdmin': isAdmin,
        'role': role.name,
        'customRoleTitle': customRoleTitle,
        'ownerEmail': ownerEmail,
        'customTrialDays': customTrialDays,
        'hasCustomTrial': hasCustomTrial,
        'idToken': idToken,
        'disabledFeatures': disabledFeatures,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final isAdminVal = json['isAdmin'] as bool? ?? false;
    final roleStr = (json['role'] as String?)?.toLowerCase();
    final parsedRole = isAdminVal
        ? UserRole.admin
        : (roleStr == 'cashier'
            ? UserRole.cashier
            : (roleStr == 'barista'
                ? UserRole.barista
                : (roleStr == 'manager'
                    ? UserRole.manager
                    : (roleStr == 'staff'
                        ? UserRole.staff
                        : (roleStr == 'admin' ? UserRole.admin : UserRole.owner)))));

    return AppUser(
      uid: json['uid'] as String? ?? 'user_1',
      email: json['email'] as String? ?? 'cashier@celestialcafe.com',
      displayName: json['displayName'] as String? ?? 'Celestial Cashier',
      photoUrl: json['photoUrl'] as String?,
      tier: (json['tier'] as String? ?? 'trial') == 'pro'
          ? SubscriptionTier.pro
          : SubscriptionTier.trial,
      trialStartDate: json['trialStartDate'] != null
          ? DateTime.tryParse(json['trialStartDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      proActivatedDate: json['proActivatedDate'] != null
          ? DateTime.tryParse(json['proActivatedDate'] as String)
          : null,
      isAdmin: isAdminVal,
      role: parsedRole,
      customRoleTitle: json['customRoleTitle'] as String?,
      ownerEmail: json['ownerEmail'] as String?,
      customTrialDays: json['customTrialDays'] as int? ?? 14,
      hasCustomTrial: json['hasCustomTrial'] as bool? ?? false,
      idToken: json['idToken'] as String?,
      disabledFeatures: (json['disabledFeatures'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class AuthService extends ChangeNotifier {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService();
    return _instance!;
  }

  // ── Storage Keys ──────────────────────────────────────────────────────────
  static const String _secureEmailKey = 'celestial_auth_email_v1';
  static const String _secureDisplayKey = 'celestial_auth_display_v1';
  static const String _securePhotoKey = 'celestial_auth_photo_v1';
  static const String _secureIdKey = 'celestial_auth_id_v1';
  static const String _secureTokenKey = 'celestial_auth_token_v1';
  static const String _prefsUserKey = 'celestial_user_session_v1';

  static const String _keyUserUid = 'celestial_auth_user_uid';
  static const String _keyUserEmail = 'celestial_auth_user_email';
  static const String _keyUserName = 'celestial_auth_user_name';
  static const String _keyUserPhoto = 'celestial_auth_user_photo';
  static const String _keyUserTier = 'celestial_auth_user_tier';
  static const String _keyTrialStart = 'celestial_auth_trial_start';
  static const String _keyIsLoggedIn = 'celestial_auth_is_logged_in';
  static const String _keyIsAdmin = 'celestial_auth_is_admin';
  static const String _keyCustomTrialDays = 'celestial_auth_custom_trial_days';
  static const String _keyDefaultTrialDays = 'celestial_auth_default_trial_days';
  static const String _keyAdminEmails = 'celestial_auth_admin_emails';
  static const String _keyManagedAccounts = 'celestial_auth_managed_accounts';
  static const String _keyPinCredentials = 'celestial_auth_pin_credentials';
  static const String _keyLastStationEmail = 'celestial_last_station_email';
  static const String _keyLastStationName = 'celestial_last_station_name';
  static const String _keyLastStationPhoto = 'celestial_last_station_photo';
  static const String _keyLastStationIsGoogle = 'celestial_last_station_is_google';
  static const String _secureStationEmailKey = 'celestial_last_station_email_v1';
  static const String _secureStationNameKey = 'celestial_last_station_name_v1';
  static const String _secureStationPhotoKey = 'celestial_last_station_photo_v1';

  // ── Secure Storage (Android Keystore / iOS Keychain / Windows DPAPI) ──────
  final _secureStorage = const FlutterSecureStorage();

  // ── Google Sign-In ────────────────────────────────────────────────────────
  static const String _defaultWebClientId =
      '533417380248-0hqfnmv71a6fo3pe9p2ghlsa28cod10l.apps.googleusercontent.com';
  static const String _defaultDesktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
    defaultValue: '533417380248-0hqfnmv71a6fo3pe9p2ghlsa28cod10l.apps.googleusercontent.com',
  );
  static const String _defaultDesktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
    defaultValue: '',
  );

  /// Returns configured Web Client ID from .env or the built-in default.
  static String get webClientId {
    try {
      final envId = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim();
      if (envId != null && envId.isNotEmpty) {
        return envId;
      }
    } catch (_) {}
    return _defaultWebClientId;
  }

  /// Builds a GoogleSignIn client instance.
  /// On Android, [serverClientId] requests an ID token from Google Play Services.
  GoogleSignIn _buildGoogleSignIn({bool withServerClientId = true}) {
    final clientId = webClientId.trim().isNotEmpty ? webClientId.trim() : _defaultWebClientId;
    return GoogleSignIn(
      clientId: kIsWeb ? clientId : null,
      serverClientId: (withServerClientId && clientId.isNotEmpty) ? clientId : null,
      scopes: const ['email', 'profile'],
    );
  }

  // ── Firebase Token Caching, Auth & Realtime Database ───────────────────────
  static const String realtimeDbUrl =
      'https://celestial-cafe-pos-2026-default-rtdb.asia-southeast1.firebasedatabase.app';
  static String get _firebaseApiKey => DefaultFirebaseOptions.currentPlatform.apiKey;
  static String? _cachedFirebaseToken;
  static DateTime? _cachedFirebaseTokenExpiry;

  static DateTime? _tokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String normalized = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final payload = json.decode(utf8.decode(base64.decode(normalized)));
      if (payload is Map<String, dynamic>) {
        final exp = payload['exp'];
        if (exp is num) {
          return DateTime.fromMillisecondsSinceEpoch(
            (exp.toInt() - 300) * 1000,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static void _cacheFirebaseToken(String token) {
    _cachedFirebaseToken = token;
    _cachedFirebaseTokenExpiry =
        _tokenExpiry(token) ?? DateTime.now().add(const Duration(minutes: 50));
  }

  static Future<String?> exchangeGoogleIdTokenForFirebase(String googleIdToken) async {
    try {
      final response = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$_firebaseApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'postBody': 'id_token=$googleIdToken&providerId=google.com',
          'requestUri': 'http://localhost',
          'returnIdpCredential': true,
          'returnSecureToken': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final fbToken = data['idToken'] as String?;
        if (fbToken != null && fbToken.isNotEmpty) {
          _cacheFirebaseToken(fbToken);
          return fbToken;
        }
      } else {
        // Expected when Desktop Google OAuth Client ID is not registered under Firebase authorized IdP clients.
        // Direct Firebase Authentication synchronization is seamlessly performed via _syncUserWithFirebase.
        debugPrint('AuthService: Note - Desktop OAuth client used; syncing via direct Firebase Authentication.');
      }
    } catch (e) {
      debugPrint('AuthService: exchangeGoogleIdTokenForFirebase exception: $e');
    }
    return null;
  }

  static bool get _isFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static Future<void> _syncUserWithFirebase(
    String email,
    String pin, {
    String? displayName,
    bool? isAdmin,
    String? tier,
    int? customTrialDays,
  }) async {
    try {
      if (_isFlutterTest) return;
      final cleanEmail = email.trim().toLowerCase();
      final fbPassword = 'celestial_pin_${cleanEmail}_$pin';

      String? authToken;

      // 1. Register or Authenticate user with Firebase Auth REST API
      final signUpRes = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_firebaseApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': cleanEmail,
          'password': fbPassword,
          'returnSecureToken': true,
        }),
      ).timeout(const Duration(seconds: 4));

      if (signUpRes.statusCode == 200) {
        final data = json.decode(signUpRes.body);
        authToken = data['idToken'] as String?;
        if (authToken != null) _cacheFirebaseToken(authToken);
        debugPrint('AuthService: Saved $cleanEmail to Firebase Authentication');
      } else {
        // 2. If already registered, sign in to refresh Firebase session
        final signInRes = await http.post(
          Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_firebaseApiKey'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': cleanEmail,
            'password': fbPassword,
            'returnSecureToken': true,
          }),
        ).timeout(const Duration(seconds: 4));
        if (signInRes.statusCode == 200) {
          final data = json.decode(signInRes.body);
          authToken = data['idToken'] as String?;
          if (authToken != null) _cacheFirebaseToken(authToken);
          debugPrint('AuthService: Authenticated $cleanEmail with Firebase');
        }
      }

      authToken ??= _cachedFirebaseToken;

      // 3. Store login email, PIN, and station data in Firebase Realtime Database
      final rtdbKey = cleanEmail.replaceAll('.', ',');
      final rtdbData = <String, dynamic>{
        'email': cleanEmail,
        'pin': pin,
        'lastLogin': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      };
      if (displayName != null && displayName.isNotEmpty) {
        rtdbData['displayName'] = displayName;
      }
      if (isAdmin != null) {
        rtdbData['isAdmin'] = isAdmin;
      }

      // Check if remote already has license & trial configurations set by Admin
      final existingRemote = await _fetchUserFromRealtimeDatabase(cleanEmail);
      if (existingRemote == null) {
        // First-time record initialization: safe to set defaults
        rtdbData['tier'] = tier ?? 'trial';
        rtdbData['customTrialDays'] = customTrialDays ?? 14;
        rtdbData['trialStartDate'] = DateTime.now().toIso8601String();
        rtdbData['hasCustomTrial'] = false;
      } else {
        // Remote record exists: preserve admin configurations and never overwrite with local defaults!
        if (existingRemote['tier'] == null && tier != null) {
          rtdbData['tier'] = tier;
        }
        if (existingRemote['customTrialDays'] == null && customTrialDays != null) {
          rtdbData['customTrialDays'] = customTrialDays;
        }
      }

      final queryParam = (authToken != null && authToken.isNotEmpty) ? '?auth=$authToken' : '';
      var rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json$queryParam');

      var rtdbRes = await http.patch(
        rtdbUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(rtdbData),
      ).timeout(const Duration(seconds: 4));

      if (rtdbRes.statusCode != 200) {
        // Fallback for public read/write test mode rules
        rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json');
        rtdbRes = await http.patch(
          rtdbUri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(rtdbData),
        ).timeout(const Duration(seconds: 4));
      }

      if (rtdbRes.statusCode == 200) {
        debugPrint('AuthService: Stored $cleanEmail & PIN on Firebase Realtime Database');
      } else {
        debugPrint('AuthService: RTDB sync note: ${rtdbRes.statusCode} ${rtdbRes.body}');
      }
    } catch (e) {
      debugPrint('AuthService: Firebase sync note: $e');
    }
  }

  static Future<void> _syncAccountTrialToRealtimeDatabase({
    required String targetEmail,
    required int customTrialDays,
    required DateTime trialStartDate,
    required String tier,
    required bool isAdmin,
  }) async {
    try {
      if (_isFlutterTest) return;
      final cleanEmail = targetEmail.trim().toLowerCase();
      final rtdbKey = cleanEmail.replaceAll('.', ',');

      final rtdbData = {
        'email': cleanEmail,
        'customTrialDays': customTrialDays,
        'hasCustomTrial': true,
        'trialStartDate': trialStartDate.toIso8601String(),
        'tier': tier,
        'isAdmin': isAdmin,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      String? authToken = _cachedFirebaseToken;
      final queryParam = (authToken != null && authToken.isNotEmpty) ? '?auth=$authToken' : '';
      var rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json$queryParam');

      var res = await http.patch(
        rtdbUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(rtdbData),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) {
        rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json');
        await http.patch(
          rtdbUri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(rtdbData),
        ).timeout(const Duration(seconds: 4));
      }
      debugPrint('AuthService: Synced custom trial ($customTrialDays days) for $cleanEmail to Firebase RTDB');
    } catch (e) {
      debugPrint('AuthService: _syncAccountTrialToRealtimeDatabase error: $e');
    }
  }

  static Future<void> _syncAccountFeaturesToRealtimeDatabase({
    required String targetEmail,
    required List<String> disabledFeatures,
  }) async {
    try {
      if (_isFlutterTest) return;
      final cleanEmail = targetEmail.trim().toLowerCase();
      final rtdbKey = cleanEmail.replaceAll('.', ',');

      final rtdbData = {
        'email': cleanEmail,
        'disabledFeatures': disabledFeatures,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      String? authToken = _cachedFirebaseToken;
      final queryParam = (authToken != null && authToken.isNotEmpty) ? '?auth=$authToken' : '';
      var rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json$queryParam');

      var res = await http.patch(
        rtdbUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(rtdbData),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) {
        rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json');
        await http.patch(
          rtdbUri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(rtdbData),
        ).timeout(const Duration(seconds: 4));
      }
      debugPrint('AuthService: Synced disabled features $disabledFeatures for $cleanEmail to Firebase RTDB');
    } catch (e) {
      debugPrint('AuthService: _syncAccountFeaturesToRealtimeDatabase error: $e');
    }
  }

  static Future<void> _syncAccountTierToRealtimeDatabase({
    required String targetEmail,
    required String tier,
    required DateTime trialStartDate,
    DateTime? proActivatedDate,
  }) async {
    try {
      if (_isFlutterTest) return;
      final cleanEmail = targetEmail.trim().toLowerCase();
      final rtdbKey = cleanEmail.replaceAll('.', ',');

      final rtdbData = {
        'email': cleanEmail,
        'tier': tier,
        'trialStartDate': trialStartDate.toIso8601String(),
        if (proActivatedDate != null) 'proActivatedDate': proActivatedDate.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      String? authToken = _cachedFirebaseToken;
      final queryParam = (authToken != null && authToken.isNotEmpty) ? '?auth=$authToken' : '';
      var rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json$queryParam');

      var res = await http.patch(
        rtdbUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(rtdbData),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) {
        rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json');
        await http.patch(
          rtdbUri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(rtdbData),
        ).timeout(const Duration(seconds: 4));
      }
      debugPrint('AuthService: Synced tier ($tier) for $cleanEmail to Firebase RTDB');
    } catch (e) {
      debugPrint('AuthService: _syncAccountTierToRealtimeDatabase error: $e');
    }
  }

  static Future<void> _deleteUserFromRealtimeDatabase(String targetEmail) async {
    try {
      if (_isFlutterTest) return;
      final cleanEmail = targetEmail.trim().toLowerCase();
      final rtdbKey = cleanEmail.replaceAll('.', ',');

      String? authToken = _cachedFirebaseToken;
      final queryParam = (authToken != null && authToken.isNotEmpty) ? '?auth=$authToken' : '';
      var rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json$queryParam');

      var res = await http.delete(rtdbUri).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) {
        rtdbUri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json');
        await http.delete(rtdbUri).timeout(const Duration(seconds: 4));
      }
      debugPrint('AuthService: Deleted $cleanEmail from Firebase RTDB');
    } catch (e) {
      debugPrint('AuthService: _deleteUserFromRealtimeDatabase error: $e');
    }
  }

  static Future<Map<String, dynamic>?> _fetchUserFromRealtimeDatabase(String email, {String? pin}) async {
    try {
      if (_isFlutterTest) return null;
      final cleanEmail = email.trim().toLowerCase();
      final rtdbKey = cleanEmail.replaceAll('.', ',');

      String? token = _cachedFirebaseToken;
      if (token == null && pin != null && pin.isNotEmpty) {
        final fbPassword = 'celestial_pin_${cleanEmail}_$pin';
        try {
          final res = await http.post(
            Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$_firebaseApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': cleanEmail,
              'password': fbPassword,
              'returnSecureToken': true,
            }),
          ).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = json.decode(res.body);
            token = data['idToken'] as String?;
            if (token != null) _cacheFirebaseToken(token);
          }
        } catch (_) {}
      }

      final queryParam = (token != null && token.isNotEmpty) ? '?auth=$token' : '';
      var uri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json$queryParam');
      var res = await http.get(uri).timeout(const Duration(seconds: 4));

      if (res.statusCode != 200) {
        uri = Uri.parse('$realtimeDbUrl/users/$rtdbKey.json');
        res = await http.get(uri).timeout(const Duration(seconds: 4));
      }

      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final decoded = json.decode(res.body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('AuthService: _fetchUserFromRealtimeDatabase error: $e');
    }
    return null;
  }

  static Future<String?> getIdToken() async {
    final cached = _cachedFirebaseToken;
    if (cached != null && cached.isNotEmpty) {
      final expiry = _cachedFirebaseTokenExpiry;
      if (expiry == null || DateTime.now().isBefore(expiry)) {
        return cached;
      }
      _cachedFirebaseToken = null;
      _cachedFirebaseTokenExpiry = null;
    }

    try {
      if (fb_auth.FirebaseAuth.instance.currentUser != null) {
        final token = await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null && token.isNotEmpty) {
          _cacheFirebaseToken(token);
          return token;
        }
      }
    } catch (_) {}

    final userToken = instance.currentUser?.idToken;
    if (userToken != null && userToken.isNotEmpty) {
      final fbToken = await exchangeGoogleIdTokenForFirebase(userToken);
      if (fbToken != null && fbToken.isNotEmpty) return fbToken;
    }

    try {
      final anonRes = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_firebaseApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'returnSecureToken': true}),
      );
      if (anonRes.statusCode == 200) {
        final data = json.decode(anonRes.body);
        final anonToken = data['idToken'] as String?;
        if (anonToken != null && anonToken.isNotEmpty) {
          _cacheFirebaseToken(anonToken);
          return anonToken;
        }
      }
    } catch (e) {
      debugPrint('AuthService: REST anonymous auth error: $e');
    }

    try {
      if (fb_auth.FirebaseAuth.instance.currentUser == null) {
        await fb_auth.FirebaseAuth.instance.signInAnonymously();
      }
      final token = await fb_auth.FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null && token.isNotEmpty) {
        _cacheFirebaseToken(token);
      }
      return token;
    } catch (e) {
      debugPrint('AuthService getIdToken error: $e');
      return null;
    }
  }

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _authStatusMessage;
  String? _errorMessage;
  bool _isFirebaseAvailable = false;
  HttpServer? _activeOAuthServer;

  List<String> _adminEmails = [
    'adminpogi6@gmail.com',
    'jccelestial04@gmail.com',
  ];
  int _defaultTrialDays = 14;
  List<AppUser> _managedAccounts = [];
  /// email.toLowerCase() → base64(email:pin) hash
  final Map<String, String> _pinCredentials = {};

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isSignedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get authStatusMessage => _authStatusMessage;
  String? get errorMessage => _errorMessage;

  /// Explicitly cancels any ongoing Google sign-in operation, closes local OAuth server, and resets loading state.
  void cancelGoogleSignIn() {
    try {
      _activeOAuthServer?.close(force: true);
    } catch (_) {}
    _activeOAuthServer = null;
    _isLoading = false;
    _authStatusMessage = null;
    _errorMessage = null;
    _pendingGoogleUser = null;
    notifyListeners();
  }
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  SubscriptionTier get currentTier => _currentUser?.tier ?? SubscriptionTier.trial;
  bool get isPro => _currentUser?.isPro ?? false;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isOwner => _currentUser?.isOwner ?? false;
  bool get isCashier => _currentUser?.isCashier ?? false;
  bool get isOwnerOrAdmin => isOwner || isAdmin;
  bool isFeatureEnabled(String featureKey) => _currentUser?.isFeatureEnabled(featureKey) ?? true;
  int get defaultTrialDays => _defaultTrialDays;
  List<String> get adminEmails => List.unmodifiable(_adminEmails);
  List<AppUser> get managedAccounts => List.unmodifiable(_managedAccounts);
  bool _isSyncingCloudAccounts = false;
  bool get isSyncingCloudAccounts => _isSyncingCloudAccounts;
  bool _needsPinSetup = false;
  bool get needsPinSetup => _needsPinSetup;

  AppUser? _pendingGoogleUser;
  AppUser? get pendingGoogleUser => _pendingGoogleUser;

  String? _lastStationEmail;
  String? get lastStationEmail => _lastStationEmail;

  String? _lastStationName;
  String? get lastStationName => _lastStationName;

  String? _lastStationPhoto;
  String? get lastStationPhoto => _lastStationPhoto;

  bool _lastStationIsGoogle = false;
  bool get lastStationIsGoogle => _lastStationIsGoogle;

  Timer? _cloudSyncTimer;

  void startCloudLicenseSyncTimer({bool forceInTest = false}) {
    _cloudSyncTimer?.cancel();
    if (!forceInTest && _isFlutterTest) return;
    if (_currentUser == null || _currentUser!.isAdmin) return;
    _cloudSyncTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_currentUser != null && !_currentUser!.isAdmin) {
        await refreshUserLicenseFromCloud();
      }
    });
  }

  void stopCloudLicenseSyncTimer() {
    _cloudSyncTimer?.cancel();
    _cloudSyncTimer = null;
  }

  Future<void> rememberStationAccount({
    required String email,
    String? displayName,
    String? photoUrl,
    bool isGoogle = false,
  }) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return;
    _lastStationEmail = clean;
    if (displayName != null && displayName.isNotEmpty) {
      _lastStationName = displayName;
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      _lastStationPhoto = photoUrl;
    }
    _lastStationIsGoogle = isGoogle;

    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyLastStationEmail, clean);
      if (_lastStationName != null) {
        await prefs.setString(_keyLastStationName, _lastStationName!);
      }
      if (_lastStationPhoto != null) {
        await prefs.setString(_keyLastStationPhoto, _lastStationPhoto!);
      }
      await prefs.setBool(_keyLastStationIsGoogle, isGoogle);
      if (!_isFlutterTest) {
        if (_lastStationName != null) {
          await _secureStorage.write(key: _secureStationNameKey, value: _lastStationName!);
        }
        if (_lastStationPhoto != null) {
          await _secureStorage.write(key: _secureStationPhotoKey, value: _lastStationPhoto!);
        }
        await _secureStorage.write(key: _secureStationEmailKey, value: clean);
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> rememberStationEmail(String email) async {
    await rememberStationAccount(email: email);
  }

  Future<void> clearRememberedStationEmail() async {
    _lastStationEmail = null;
    _lastStationName = null;
    _lastStationPhoto = null;
    _lastStationIsGoogle = false;
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyLastStationEmail);
      await prefs.remove(_keyLastStationName);
      await prefs.remove(_keyLastStationPhoto);
      await prefs.remove(_keyLastStationIsGoogle);
      if (!_isFlutterTest) {
        await _secureStorage.delete(key: _secureStationEmailKey);
        await _secureStorage.delete(key: _secureStationNameKey);
        await _secureStorage.delete(key: _secureStationPhotoKey);
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Silently inspects if an active Google session is authorized on device (Android/iOS/Web/macOS).
  /// If found, populates recent login information so the user immediately sees their Google account.
  Future<void> checkActiveGoogleSession() async {
    if (_isFlutterTest) return;
    if (!kIsWeb &&
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return;
    }
    try {
      final googleSignIn = _buildGoogleSignIn(withServerClientId: false);
      final account = await googleSignIn.signInSilently().timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => null,
      );
      if (account != null) {
        await rememberStationAccount(
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
          isGoogle: true,
        );
      }
    } catch (e) {
      debugPrint('AuthService: checkActiveGoogleSession note: $e');
    }
  }

  Future<void> init() => _ensureInitialized();

  void markPinSetupHandled() {
    _needsPinSetup = false;
  }

  bool hasPin(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    return _pinCredentials.containsKey(email.trim().toLowerCase());
  }

  bool verifyPin(String email, String pin) {
    final cleanEmail = email.trim().toLowerCase();
    final storedHash = _pinCredentials[cleanEmail];
    if (storedHash == null) return false;
    return storedHash == _hashPin(cleanEmail, pin);
  }

  /// Checks Firebase Realtime Database to see if an account was registered on another station or phone.
  Future<bool> checkRemoteHasPin(String? email) async {
    if (email == null || email.trim().isEmpty) return false;
    try {
      final remote = await _fetchUserFromRealtimeDatabase(email);
      if (remote != null && remote['pin'] != null && remote['pin'].toString().isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> setPinForUser({
    required String email,
    required String pin,
    bool autoSignIn = true,
    bool isUpdate = false,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (pin.length != 4 || int.tryParse(pin) == null) {
      _errorMessage = 'PIN must be exactly 4 digits.';
      notifyListeners();
      return false;
    }

    final bool isCurrentUser = _currentUser != null && _currentUser!.email.toLowerCase() == cleanEmail;
    final bool isAdminActing = _currentUser != null && _currentUser!.isAdmin;
    final bool shouldPermitUpdate = isUpdate || isCurrentUser || isAdminActing;

    if (!shouldPermitUpdate) {
      if (_pinCredentials.containsKey(cleanEmail)) {
        final storedHash = _pinCredentials[cleanEmail];
        if (storedHash == _hashPin(cleanEmail, pin)) {
          if (autoSignIn) {
            return await signInWithPin(email: cleanEmail, pin: pin);
          } else {
            await rememberStationAccount(
              email: cleanEmail,
              displayName: _pendingGoogleUser?.displayName,
              photoUrl: _pendingGoogleUser?.photoUrl,
              isGoogle: cleanEmail.endsWith('@gmail.com') || _pendingGoogleUser != null,
            );
            _pendingGoogleUser = null;
            _needsPinSetup = false;
            notifyListeners();
            return true;
          }
        } else {
          _errorMessage = 'An account with this email already exists. Incorrect PIN.';
          notifyListeners();
          return false;
        }
      }

      if (await checkRemoteHasPin(cleanEmail)) {
        final remote = await _fetchUserFromRealtimeDatabase(cleanEmail, pin: pin);
        if (remote != null) {
          if (remote['pin']?.toString() == pin) {
            if (autoSignIn) {
              return await signInWithPin(email: cleanEmail, pin: pin);
            } else {
              _pinCredentials[cleanEmail] = _hashPin(cleanEmail, pin);
              await _persistPinCredentials();
              await rememberStationAccount(
                email: cleanEmail,
                displayName: _pendingGoogleUser?.displayName ?? remote['displayName']?.toString(),
                photoUrl: _pendingGoogleUser?.photoUrl ?? remote['photoUrl']?.toString(),
                isGoogle: cleanEmail.endsWith('@gmail.com') || _pendingGoogleUser != null,
              );
              _pendingGoogleUser = null;
              _needsPinSetup = false;
              notifyListeners();
              return true;
            }
          } else {
            _errorMessage = 'An account with this email already exists. Incorrect PIN.';
            notifyListeners();
            return false;
          }
        }
      }
    }

    _pinCredentials[cleanEmail] = _hashPin(cleanEmail, pin);
    await _persistPinCredentials();

    final isAdminUser = checkIfAdmin(cleanEmail);
    final AppUser userToRegister;
    if (_pendingGoogleUser != null && _pendingGoogleUser!.email.toLowerCase() == cleanEmail) {
      userToRegister = _pendingGoogleUser!.copyWith(
        isAdmin: isAdminUser,
        tier: isAdminUser ? SubscriptionTier.pro : _pendingGoogleUser!.tier,
      );
    } else {
      final displayName = cleanEmail.split('@').first;
      final uid = 'pin_${cleanEmail.hashCode.abs()}';
      final existingManaged = _managedAccounts.firstWhere(
        (a) => a.email.toLowerCase() == cleanEmail,
        orElse: () => AppUser(
          uid: uid,
          email: cleanEmail,
          displayName: displayName,
          trialStartDate: DateTime.now(),
          tier: isAdminUser ? SubscriptionTier.pro : SubscriptionTier.trial,
          customTrialDays: _defaultTrialDays,
          isAdmin: isAdminUser,
        ),
      );
      userToRegister = AppUser(
        uid: existingManaged.uid.isEmpty ? uid : existingManaged.uid,
        email: cleanEmail,
        displayName: existingManaged.displayName.isNotEmpty ? existingManaged.displayName : displayName,
        photoUrl: existingManaged.photoUrl,
        tier: isAdminUser ? SubscriptionTier.pro : existingManaged.tier,
        trialStartDate: existingManaged.trialStartDate,
        proActivatedDate: existingManaged.proActivatedDate,
        isAdmin: isAdminUser,
        customTrialDays: existingManaged.customTrialDays,
        hasCustomTrial: existingManaged.hasCustomTrial,
        disabledFeatures: existingManaged.disabledFeatures,
      );
    }

    _upsertManagedAccount(userToRegister);
    await _persistManagedAccounts();

    await rememberStationAccount(
      email: cleanEmail,
      displayName: userToRegister.displayName,
      photoUrl: userToRegister.photoUrl,
      isGoogle: cleanEmail.endsWith('@gmail.com') || _pendingGoogleUser != null,
    );

    if (isCurrentUser) {
      _currentUser = _currentUser!.copyWith(
        displayName: _currentUser!.displayName.isNotEmpty ? _currentUser!.displayName : userToRegister.displayName,
      );
      await _persistUser(_currentUser!);
    } else if (isAdminActing) {
      // Admin updated another user's PIN: preserve admin's active session
    } else if (autoSignIn) {
      _currentUser = userToRegister;
      await _persistUser(_currentUser!);
      if (_currentUser != null && !_currentUser!.isAdmin) {
        startCloudLicenseSyncTimer();
      }
    } else {
      _currentUser = null;
    }

    _pendingGoogleUser = null;
    _needsPinSetup = false;
    notifyListeners();

    unawaited(_syncUserWithFirebase(
      cleanEmail,
      pin,
      displayName: userToRegister.displayName.isNotEmpty ? userToRegister.displayName : cleanEmail.split('@').first,
      isAdmin: isAdminUser,
      tier: userToRegister.tier.name,
      customTrialDays: userToRegister.customTrialDays,
    ));

    return true;
  }

  List<String> get registeredEmails => List.unmodifiable(_pinCredentials.keys.toList());
  bool isEmailRegistered(String email) => _pinCredentials.containsKey(email.trim().toLowerCase());

  AuthService({AppUser? initialUser}) : _currentUser = initialUser {
    _instance = this;
    if (initialUser == null) {
      _initAuth();
    } else {
      _managedAccounts = [initialUser];
    }
  }

  void setLoggedInUserForTesting(AppUser user) {
    _currentUser = user;
    if (!_managedAccounts.any((a) => a.uid == user.uid)) {
      _managedAccounts.add(user);
    }
    notifyListeners();
  }

  void setStationEmailForTesting(
    String email, {
    String? displayName,
    String? photoUrl,
    bool isGoogle = false,
  }) {
    _lastStationEmail = email.trim().toLowerCase();
    _lastStationName = displayName;
    _lastStationPhoto = photoUrl;
    _lastStationIsGoogle = isGoogle;
    notifyListeners();
  }

  void registerPinForTesting(String email, String pin) {
    final clean = email.trim().toLowerCase();
    _pinCredentials[clean] = _hashPin(clean, pin);
    _getPrefs().then((prefs) {
      prefs.setString(_keyPinCredentials, jsonEncode(_pinCredentials));
    }).catchError((_) {});
  }

  void setLoadingForTesting(bool loading, {String? statusMessage}) {
    _isLoading = loading;
    _authStatusMessage = statusMessage;
    notifyListeners();
  }

  void setPendingGoogleUserForTesting(AppUser? user) {
    _pendingGoogleUser = user;
    notifyListeners();
  }

  bool checkIfAdmin(String email) {
    final clean = email.trim().toLowerCase();
    return _adminEmails.any((e) => e.toLowerCase() == clean);
  }

  static bool isCurrentUserAdmin(String? email) {
    if (email == null) return false;
    final clean = email.trim().toLowerCase();
    final currentEmail = instance.currentUser?.email.toLowerCase();
    if (clean == currentEmail) {
      return instance.currentUser?.isAdmin ?? false;
    }
    return instance.checkIfAdmin(clean);
  }

  Completer<void>? _initCompleter;

  Future<void> _ensureInitialized() async {
    if (_initCompleter != null) {
      await _initCompleter!.future;
    } else {
      await _initAuth();
    }
  }

  Future<void> _initAuth() async {
    if (_initCompleter != null) return _initCompleter!.future;
    final completer = Completer<void>();
    _initCompleter = completer;

    try {
      if (!kIsWeb && !_isFlutterTest) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          ).timeout(const Duration(seconds: 2));
        }
        _isFirebaseAvailable = true;
      }
    } catch (e) {
      debugPrint('Firebase Core init note (using adaptive auth): $e');
      _isFirebaseAvailable = false;
    }

    try {
      await _loadAdminSettings();
      await _loadSavedUser();
      unawaited(syncManagedAccountsFromCloud());
    } catch (e) {
      debugPrint('Error in _initAuth data loading: $e');
    } finally {
      if (!completer.isCompleted) completer.complete();
    }
    notifyListeners();
  }

  Future<SharedPreferences> _getPrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      return await SharedPreferences.getInstance();
    }
  }

  Future<void> _loadAdminSettings() async {
    try {
      final prefs = await _getPrefs();
      final savedAdminEmails = prefs.getStringList(_keyAdminEmails);
      if (savedAdminEmails != null && savedAdminEmails.isNotEmpty) {
        _adminEmails = savedAdminEmails
            .where((e) =>
                e.toLowerCase() != 'celestial.admin@gmail.com' &&
                e.toLowerCase() != 'admin@celestialcafe.com')
            .toList();
        if (!_adminEmails.any((e) => e.toLowerCase() == 'adminpogi6@gmail.com')) {
          _adminEmails.add('adminpogi6@gmail.com');
        }
        if (!_adminEmails.any((e) => e.toLowerCase() == 'jccelestial04@gmail.com')) {
          _adminEmails.add('jccelestial04@gmail.com');
        }
      } else {
        _adminEmails = ['adminpogi6@gmail.com', 'jccelestial04@gmail.com'];
      }

      _defaultTrialDays = prefs.getInt(_keyDefaultTrialDays) ?? 14;

      final accountsJson = prefs.getString(_keyManagedAccounts);
      if (accountsJson != null && accountsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(accountsJson);
        _managedAccounts = decoded.map((item) {
          final acc = AppUser.fromJson(item as Map<String, dynamic>);
          if (!acc.hasCustomTrial && !acc.isAdmin) {
            return acc.copyWith(customTrialDays: _defaultTrialDays);
          }
          return acc;
        }).toList();
      } else {
        _managedAccounts = [
          AppUser(
            uid: 'terminal_1',
            email: 'cashier1@celestialcafe.com',
            displayName: 'Main Front Cashier',
            tier: SubscriptionTier.trial,
            trialStartDate: DateTime.now().subtract(const Duration(days: 2)),
            customTrialDays: _defaultTrialDays,
          ),
          AppUser(
            uid: 'terminal_2',
            email: 'patio.terminal@gmail.com',
            displayName: 'Outdoor Patio Station',
            tier: SubscriptionTier.pro,
            trialStartDate: DateTime.now().subtract(const Duration(days: 20)),
            proActivatedDate: DateTime.now().subtract(const Duration(days: 10)),
            customTrialDays: _defaultTrialDays,
          ),
          AppUser(
            uid: 'terminal_3',
            email: 'express.lane@celestialcafe.com',
            displayName: 'Express Pickup Station',
            tier: SubscriptionTier.trial,
            trialStartDate: DateTime.now().subtract(const Duration(days: 9)),
            customTrialDays: _defaultTrialDays,
          ),
        ];
        await _persistManagedAccounts();
      }

      // Load PIN credentials
      final pinJson = prefs.getString(_keyPinCredentials);
      if (pinJson != null && pinJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(pinJson);
        decoded.forEach((k, v) => _pinCredentials[k] = v as String);
      } else {
        try {
          final secPin = await _secureStorage.read(key: 'celestial_auth_pin_credentials_v1');
          if (secPin != null && secPin.isNotEmpty) {
            final Map<String, dynamic> decoded = jsonDecode(secPin);
            decoded.forEach((k, v) => _pinCredentials[k] = v as String);
            await prefs.setString(_keyPinCredentials, secPin);
          }
        } catch (_) {}
      }

      // Load remembered station email so cashiers/users only need to enter their PIN
      final savedStationEmail = prefs.getString(_keyLastStationEmail);
      if (savedStationEmail != null && savedStationEmail.isNotEmpty) {
        _lastStationEmail = savedStationEmail.trim().toLowerCase();
      } else {
        try {
          final secEmail = await _secureStorage.read(key: _secureStationEmailKey);
          if (secEmail != null && secEmail.isNotEmpty) {
            _lastStationEmail = secEmail.trim().toLowerCase();
            await prefs.setString(_keyLastStationEmail, _lastStationEmail!);
          }
        } catch (_) {}
      }

      _lastStationName = prefs.getString(_keyLastStationName);
      _lastStationPhoto = prefs.getString(_keyLastStationPhoto);
      _lastStationIsGoogle = prefs.getBool(_keyLastStationIsGoogle) ?? false;
      if (_lastStationName == null || _lastStationPhoto == null) {
        try {
          _lastStationName ??= await _secureStorage.read(key: _secureStationNameKey);
          _lastStationPhoto ??= await _secureStorage.read(key: _secureStationPhotoKey);
        } catch (_) {}
      }

      if (_lastStationEmail != null && _lastStationEmail!.isNotEmpty) {
        if (_lastStationName == null || _lastStationName!.isEmpty) {
          final matchingAcc = _managedAccounts.cast<AppUser?>().firstWhere(
            (a) => a != null && a.email.toLowerCase() == _lastStationEmail,
            orElse: () => null,
          );
          if (matchingAcc != null) {
            _lastStationName = matchingAcc.displayName;
            _lastStationPhoto ??= matchingAcc.photoUrl;
          }
        }
        if (!_lastStationIsGoogle && _lastStationEmail!.endsWith('@gmail.com')) {
          _lastStationIsGoogle = true;
        }
      }

      if (_lastStationEmail == null || _lastStationEmail!.isEmpty) {
        if (_pinCredentials.isNotEmpty) {
          _lastStationEmail = _pinCredentials.keys.first.trim().toLowerCase();
          await prefs.setString(_keyLastStationEmail, _lastStationEmail!);
        } else {
          final accountWithPin = _managedAccounts.cast<AppUser?>().firstWhere(
            (a) => a != null && _pinCredentials.containsKey(a.email.trim().toLowerCase()),
            orElse: () => null,
          );
          if (accountWithPin != null) {
            _lastStationEmail = accountWithPin.email.trim().toLowerCase();
            await prefs.setString(_keyLastStationEmail, _lastStationEmail!);
          }
        }
      }

      if (_currentUser != null) {
        _upsertManagedAccount(_currentUser!);
      }
    } catch (e) {
      debugPrint('Error loading admin settings: $e');
    }
  }

  Future<void> _writeToSecureStorage(AppUser user) async {
    if (_isFlutterTest) return;
    try {
      await _clearSecureStorage();
      await _secureStorage.write(key: _secureEmailKey, value: user.email);
      await _secureStorage.write(key: _secureDisplayKey, value: user.displayName);
      await _secureStorage.write(key: _secureIdKey, value: user.uid);
      await _secureStorage.write(key: _securePhotoKey, value: user.photoUrl ?? '');
      if (user.idToken != null && user.idToken!.isNotEmpty) {
        await _secureStorage.write(key: _secureTokenKey, value: user.idToken!);
      }
    } catch (e) {
      debugPrint('AuthService: Secure storage write note: $e');
    }
  }

  Future<void> _clearSecureStorage() async {
    if (_isFlutterTest) return;
    try {
      await _secureStorage.delete(key: _secureEmailKey);
      await _secureStorage.delete(key: _secureDisplayKey);
      await _secureStorage.delete(key: _securePhotoKey);
      await _secureStorage.delete(key: _secureIdKey);
      await _secureStorage.delete(key: _secureTokenKey);
    } catch (e) {
      debugPrint('AuthService: Secure storage clear note: $e');
    }
  }

  Future<void> _loadSavedUser() async {
    try {
      final prefs = await _getPrefs();

      // 1. Primary: Try SharedPreferences JSON cache
      final savedUserJson = prefs.getString(_prefsUserKey);
      if (savedUserJson != null && savedUserJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedUserJson) as Map<String, dynamic>;
          final user = AppUser.fromJson(decoded);
          final cleanEmail = user.email.toLowerCase();
          final isAdminStored = checkIfAdmin(cleanEmail);

          // Find any managed account entry configured by admin
          final managedIdx = _managedAccounts.indexWhere(
            (a) => a.email.toLowerCase() == cleanEmail || a.uid == user.uid,
          );

          if (managedIdx >= 0) {
            final managed = _managedAccounts[managedIdx];
            _currentUser = user.copyWith(
              displayName: managed.displayName.isNotEmpty ? managed.displayName : user.displayName,
              isAdmin: isAdminStored || user.isAdmin || managed.isAdmin,
              role: managed.role,
              ownerEmail: managed.ownerEmail ?? user.ownerEmail,
              tier: (isAdminStored || user.isAdmin || managed.isAdmin)
                  ? SubscriptionTier.pro
                  : managed.tier,
              customTrialDays: managed.hasCustomTrial
                  ? managed.customTrialDays
                  : (!user.hasCustomTrial ? _defaultTrialDays : user.customTrialDays),
              hasCustomTrial: managed.hasCustomTrial || user.hasCustomTrial,
              trialStartDate: managed.trialStartDate,
              proActivatedDate: managed.proActivatedDate ?? user.proActivatedDate,
              disabledFeatures: managed.disabledFeatures.isNotEmpty ? managed.disabledFeatures : user.disabledFeatures,
            );
          } else {
            _currentUser = user.copyWith(
              isAdmin: isAdminStored || user.isAdmin,
              customTrialDays: (!user.hasCustomTrial && !user.isAdmin) ? _defaultTrialDays : user.customTrialDays,
            );
          }

          debugPrint('AuthService: Session restored and synced from SharedPreferences [${user.email}]');
          _writeToSecureStorage(_currentUser!);
          if (_currentUser != null && !_currentUser!.isAdmin) {
            startCloudLicenseSyncTimer();
          }
          return;
        } catch (_) {}
      }

      // 2. Legacy key restoration from SharedPreferences
      final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
      if (isLoggedIn) {
        final uid = prefs.getString(_keyUserUid) ?? 'user_default';
        final email = prefs.getString(_keyUserEmail) ?? 'cashier@celestialcafe.com';
        final name = prefs.getString(_keyUserName) ?? 'Celestial Cashier';
        final photo = prefs.getString(_keyUserPhoto);
        final tierStr = prefs.getString(_keyUserTier) ?? 'trial';
        final trialStartStr = prefs.getString(_keyTrialStart);
        final trialStart = trialStartStr != null
            ? DateTime.tryParse(trialStartStr) ?? DateTime.now()
            : DateTime.now();
        final isAdminStored = checkIfAdmin(email);
        final customTrial = prefs.getInt(_keyCustomTrialDays) ?? 14;

        _currentUser = AppUser(
          uid: uid,
          email: email,
          displayName: name,
          photoUrl: photo,
          tier: (isAdminStored || tierStr == 'pro') ? SubscriptionTier.pro : SubscriptionTier.trial,
          trialStartDate: trialStart,
          isAdmin: isAdminStored,
          customTrialDays: customTrial,
        );
        _writeToSecureStorage(_currentUser!);
        await prefs.setString(_prefsUserKey, jsonEncode(_currentUser!.toJson()));
        return;
      }

      // 3. Fallback: Recover session from Secure Storage (survives app reinstalls)
      try {
        final email = await _secureStorage.read(key: _secureEmailKey);
        if (email != null && email.isNotEmpty) {
          final displayName = await _secureStorage.read(key: _secureDisplayKey) ?? email.split('@').first;
          final photoRaw = await _secureStorage.read(key: _securePhotoKey);
          final photoUrl = (photoRaw != null && photoRaw.isNotEmpty) ? photoRaw : null;
          final uid = await _secureStorage.read(key: _secureIdKey) ?? 'secure_user_${email.hashCode.abs()}';
          final token = await _secureStorage.read(key: _secureTokenKey);
          final isAdminStored = checkIfAdmin(email);

          _currentUser = AppUser(
            uid: uid,
            email: email,
            displayName: displayName,
            photoUrl: photoUrl,
            tier: isAdminStored ? SubscriptionTier.pro : SubscriptionTier.trial,
            trialStartDate: DateTime.now(),
            isAdmin: isAdminStored,
            customTrialDays: _defaultTrialDays,
            idToken: token,
          );
          await prefs.setBool(_keyIsLoggedIn, true);
          await prefs.setString(_prefsUserKey, jsonEncode(_currentUser!.toJson()));
          debugPrint('AuthService: Session recovered from secure storage [$email]');
        }
      } catch (secErr) {
        debugPrint('AuthService: Secure storage read error: $secErr');
      }
    } catch (e) {
      debugPrint('Error loading saved auth session: $e');
    }
  }

  Future<void> _persistUser(AppUser user) async {
    try {
      await _writeToSecureStorage(user);

      final prefs = await _getPrefs();
      await prefs.setBool(_keyIsLoggedIn, true);
      await prefs.setString(_keyUserUid, user.uid);
      await prefs.setString(_keyUserEmail, user.email);
      await prefs.setString(_keyUserName, user.displayName);
      if (user.photoUrl != null) {
        await prefs.setString(_keyUserPhoto, user.photoUrl!);
      } else {
        await prefs.remove(_keyUserPhoto);
      }
      await prefs.setString(_keyUserTier, user.tier.name);
      await prefs.setString(_keyTrialStart, user.trialStartDate.toIso8601String());
      await prefs.setBool(_keyIsAdmin, user.isAdmin);
      await prefs.setInt(_keyCustomTrialDays, user.customTrialDays);
      await prefs.setString(_prefsUserKey, jsonEncode(user.toJson()));
      await rememberStationEmail(user.email);

      _upsertManagedAccount(user);
      await _persistManagedAccounts();
    } catch (e) {
      debugPrint('Error persisting user session: $e');
    }
  }

  void _upsertManagedAccount(AppUser user) {
    final cleanEmail = user.email.trim().toLowerCase();
    final idx = _managedAccounts.indexWhere(
      (a) => a.uid == user.uid || a.email.trim().toLowerCase() == cleanEmail,
    );
    if (idx >= 0) {
      final existing = _managedAccounts[idx];
      final effectiveCustomTrial = existing.hasCustomTrial || user.hasCustomTrial;
      final effectiveDays = user.hasCustomTrial
          ? user.customTrialDays
          : (existing.hasCustomTrial ? existing.customTrialDays : user.customTrialDays);
      final effectiveTier = (existing.tier == SubscriptionTier.pro || user.tier == SubscriptionTier.pro)
          ? SubscriptionTier.pro
          : SubscriptionTier.trial;
      final effectiveDisabledFeatures = user.disabledFeatures.isNotEmpty
          ? user.disabledFeatures
          : existing.disabledFeatures;

      final effectiveRole = existing.role != UserRole.owner ? existing.role : user.role;
      final effectiveOwnerEmail = existing.ownerEmail ?? user.ownerEmail;

      _managedAccounts[idx] = user.copyWith(
        hasCustomTrial: effectiveCustomTrial,
        customTrialDays: effectiveDays,
        tier: effectiveTier,
        role: effectiveRole,
        ownerEmail: effectiveOwnerEmail,
        trialStartDate: (existing.hasCustomTrial && !existing.isTrialExpired)
            ? existing.trialStartDate
            : user.trialStartDate,
        disabledFeatures: effectiveDisabledFeatures,
      );
    } else {
      _managedAccounts.add(user);
    }
  }

  Future<void> _persistManagedAccounts() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(_managedAccounts.map((a) => a.toJson()).toList());
      await prefs.setString(_keyManagedAccounts, jsonStr);
    } catch (e) {
      debugPrint('Error persisting managed accounts: $e');
    }
  }

  Future<void> _persistPinCredentials() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = jsonEncode(_pinCredentials);
      await prefs.setString(_keyPinCredentials, jsonStr);
      if (!_isFlutterTest) {
        try {
          await _secureStorage.write(key: 'celestial_auth_pin_credentials_v1', value: jsonStr);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error persisting PIN credentials: $e');
    }
  }

  /// Lightweight, dependency-free PIN hash: base64(email:pin)
  String _hashPin(String email, String pin) {
    final raw = '${email.trim().toLowerCase()}:$pin';
    return base64Encode(utf8.encode(raw));
  }

  // --- Register with Gmail + PIN ---
  Future<bool> registerWithPin({
    required String email,
    required String pin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 200));

    final cleanEmail = email.trim().toLowerCase();

    if (pin.length != 4 || int.tryParse(pin) == null) {
      _errorMessage = 'PIN must be exactly 4 digits.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (_pinCredentials.containsKey(cleanEmail)) {
      _errorMessage = 'An account with this email already exists. Please sign in.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final isAdminUser = checkIfAdmin(cleanEmail);
    final displayName = cleanEmail.split('@').first;
    final uid = 'pin_${cleanEmail.hashCode.abs()}';

    // Check if admin-assigned account already exists for this email
    final existingManaged = _managedAccounts.firstWhere(
      (a) => a.email.toLowerCase() == cleanEmail,
      orElse: () => AppUser(
        uid: uid,
        email: cleanEmail,
        displayName: displayName,
        trialStartDate: DateTime.now(),
        tier: isAdminUser ? SubscriptionTier.pro : SubscriptionTier.trial,
        customTrialDays: _defaultTrialDays,
        isAdmin: isAdminUser,
      ),
    );

    _currentUser = AppUser(
      uid: existingManaged.uid == '' ? uid : existingManaged.uid,
      email: cleanEmail,
      displayName: displayName,
      photoUrl: null,
      tier: isAdminUser ? SubscriptionTier.pro : (existingManaged.tier),
      trialStartDate: existingManaged.trialStartDate,
      proActivatedDate: existingManaged.proActivatedDate,
      isAdmin: isAdminUser,
      customTrialDays: existingManaged.customTrialDays,
    );

    _pinCredentials[cleanEmail] = _hashPin(cleanEmail, pin);
    await _persistPinCredentials();
    await _persistUser(_currentUser!);
    await rememberStationEmail(cleanEmail);

    // Sync with Firebase Authentication & Realtime Database so user and PIN are saved on cloud
    unawaited(_syncUserWithFirebase(
      cleanEmail,
      pin,
      displayName: displayName,
      isAdmin: isAdminUser,
      tier: (isAdminUser ? 'pro' : existingManaged.tier.name),
      customTrialDays: existingManaged.customTrialDays,
    ));

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // --- Sign In with Gmail + PIN ---
  Future<bool> signInWithPin({
    required String email,
    required String pin,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 200));

    // Resolve identifier (Cashier Name, Station Label, Username, or Email) to account email
    final resolvedCashier = findCashierByIdentifier(email);
    final cleanEmail = (resolvedCashier != null ? resolvedCashier.email : email).trim().toLowerCase();
    final storedHash = _pinCredentials[cleanEmail];

    if (storedHash == null) {
      if (!cleanEmail.contains('@')) {
        _errorMessage = 'No staff account found with name "$email". Please check with your Store Owner.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      // Check Firebase Realtime Database in case user registered on another station or phone
      final remoteUser = await _fetchUserFromRealtimeDatabase(cleanEmail, pin: pin);
      if (remoteUser != null) {
        if (remoteUser['pin']?.toString() == pin) {
          _pinCredentials[cleanEmail] = _hashPin(cleanEmail, pin);
          await _persistPinCredentials();
          final isAdminUser = checkIfAdmin(cleanEmail) || (remoteUser['isAdmin'] == true);
          final isPendingGoogle = _pendingGoogleUser != null && _pendingGoogleUser!.email.toLowerCase() == cleanEmail;
          final photo = isPendingGoogle ? _pendingGoogleUser!.photoUrl : remoteUser['photoUrl']?.toString();
          final displayName = (isPendingGoogle && _pendingGoogleUser!.displayName.isNotEmpty)
              ? _pendingGoogleUser!.displayName
              : (remoteUser['displayName']?.toString() ?? cleanEmail.split('@').first);
          final token = isPendingGoogle ? _pendingGoogleUser!.idToken : remoteUser['idToken']?.toString();

          final restoredUser = AppUser(
            uid: remoteUser['uid']?.toString() ?? 'rtdb_${cleanEmail.hashCode.abs()}',
            email: cleanEmail,
            displayName: displayName,
            photoUrl: photo,
            tier: (remoteUser['tier'] == 'pro' || isAdminUser) ? SubscriptionTier.pro : SubscriptionTier.trial,
            trialStartDate: DateTime.tryParse(remoteUser['trialStartDate']?.toString() ?? '') ?? DateTime.now(),
            customTrialDays: (remoteUser['customTrialDays'] as num?)?.toInt() ?? _defaultTrialDays,
            hasCustomTrial: remoteUser['hasCustomTrial'] == true || remoteUser['customTrialDays'] != null,
            isAdmin: isAdminUser,
            idToken: token,
          );
          _currentUser = restoredUser;
          _pendingGoogleUser = null;
          _upsertManagedAccount(restoredUser);
          await _persistManagedAccounts();
          await _persistUser(restoredUser);
          await rememberStationAccount(
            email: cleanEmail,
            displayName: restoredUser.displayName,
            photoUrl: restoredUser.photoUrl,
            isGoogle: cleanEmail.endsWith('@gmail.com'),
          );
          if (_currentUser != null && !_currentUser!.isAdmin) {
            startCloudLicenseSyncTimer();
          }
          _isLoading = false;
          notifyListeners();
          unawaited(_syncUserWithFirebase(
            cleanEmail,
            pin,
            displayName: restoredUser.displayName,
            isAdmin: isAdminUser,
            tier: restoredUser.tier.name,
            customTrialDays: restoredUser.customTrialDays,
          ));
          return true;
        } else {
          _errorMessage = 'Incorrect PIN. Please try again.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      if (checkIfAdmin(cleanEmail)) {
        return await setPinForUser(email: cleanEmail, pin: pin);
      }
      _errorMessage = 'No account found for this email. Please register first.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (storedHash != _hashPin(cleanEmail, pin)) {
      _errorMessage = 'Incorrect PIN. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final isAdminUser = checkIfAdmin(cleanEmail);
    if (_pendingGoogleUser != null && _pendingGoogleUser!.email.toLowerCase() == cleanEmail) {
      _currentUser = _pendingGoogleUser!.copyWith(
        isAdmin: isAdminUser,
        tier: isAdminUser ? SubscriptionTier.pro : _pendingGoogleUser!.tier,
      );
      _pendingGoogleUser = null;
    } else {
      // Restore admin-configured account data if available
      AppUser existingAccount = _managedAccounts.firstWhere(
        (a) => a.email.toLowerCase() == cleanEmail,
        orElse: () => AppUser(
          uid: 'pin_${cleanEmail.hashCode.abs()}',
          email: cleanEmail,
          displayName: cleanEmail.split('@').first,
          trialStartDate: DateTime.now(),
          customTrialDays: _defaultTrialDays,
        ),
      );

      // Fetch cloud license to ensure admin custom trial days / tier are synced immediately
      try {
        final remote = await _fetchUserFromRealtimeDatabase(cleanEmail, pin: pin);
        if (remote != null) {
          final remoteDays = (remote['customTrialDays'] as num?)?.toInt();
          final remoteStart = DateTime.tryParse(remote['trialStartDate']?.toString() ?? '');
          final remoteTierStr = remote['tier']?.toString();
          final remoteIsAdmin = remote['isAdmin'] == true || isAdminUser;
          final remoteTier = (remoteTierStr == 'pro' || remoteIsAdmin) ? SubscriptionTier.pro : SubscriptionTier.trial;

          existingAccount = existingAccount.copyWith(
            customTrialDays: remoteDays ?? existingAccount.customTrialDays,
            hasCustomTrial: remote['hasCustomTrial'] == true || remoteDays != null || existingAccount.hasCustomTrial,
            trialStartDate: remoteStart ?? existingAccount.trialStartDate,
            tier: remoteTier,
            isAdmin: remoteIsAdmin,
          );
        }
      } catch (remoteErr) {
        debugPrint('AuthService: remote sync note on pin sign-in: $remoteErr');
      }

      _currentUser = existingAccount.copyWith(
        isAdmin: isAdminUser || existingAccount.isAdmin,
        tier: (isAdminUser || existingAccount.isAdmin) ? SubscriptionTier.pro : existingAccount.tier,
      );
    }

    _upsertManagedAccount(_currentUser!);
    await _persistManagedAccounts();
    await _persistUser(_currentUser!);
    await rememberStationAccount(
      email: cleanEmail,
      displayName: _currentUser?.displayName,
      photoUrl: _currentUser?.photoUrl,
      isGoogle: cleanEmail.endsWith('@gmail.com'),
    );

    if (_currentUser != null && !_currentUser!.isAdmin) {
      startCloudLicenseSyncTimer();
    }

    // Sync session and PIN with Firebase Realtime Database
    unawaited(_syncUserWithFirebase(
      cleanEmail,
      pin,
      displayName: _currentUser?.displayName,
      isAdmin: isAdminUser,
      tier: _currentUser?.tier.name,
      customTrialDays: _currentUser?.customTrialDays,
    ));

    _isLoading = false;
    notifyListeners();
    return true;
  }

  // --- Sign In with PIN Only (Fast Mobile POS PIN Station) ---
  Future<bool> signInWithPinOnly(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.length != 4 || int.tryParse(cleanPin) == null) {
      _errorMessage = 'PIN must be exactly 4 digits.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // 1. If station email is remembered, attempt direct PIN sign-in
    if (_lastStationEmail != null && _lastStationEmail!.isNotEmpty) {
      final success = await signInWithPin(email: _lastStationEmail!, pin: cleanPin);
      if (success) return true;
    }

    // 2. Check local PIN credentials for any account matching this PIN
    for (final entry in _pinCredentials.entries) {
      final email = entry.key;
      final storedHash = entry.value;
      if (storedHash == _hashPin(email, cleanPin)) {
        final success = await signInWithPin(email: email, pin: cleanPin);
        if (success) return true;
      }
    }

    // 3. Check Firebase Realtime Database (/users.json) for matching PIN
    try {
      final url = Uri.parse('$realtimeDbUrl/users.json');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body.isNotEmpty && response.body != 'null') {
        final Map<String, dynamic> users = jsonDecode(response.body);
        for (final entry in users.entries) {
          final userData = entry.value;
          if (userData is Map && userData['pin']?.toString() == cleanPin) {
            final email = (userData['email']?.toString() ?? entry.key.replaceAll(',', '.')).trim().toLowerCase();
            if (email.isNotEmpty) {
              final success = await signInWithPin(email: email, pin: cleanPin);
              if (success) return true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Realtime Database pin-only lookup note: $e');
    }

    _isLoading = false;
    _errorMessage = 'Incorrect PIN. Please try again.';
    notifyListeners();
    return false;
  }

  // --- Admin: Reset a user's PIN ---
  Future<bool> resetAccountPin(String email, String newPin) async {
    if (newPin.length != 4 || int.tryParse(newPin) == null) return false;
    final cleanEmail = email.trim().toLowerCase();
    if (!_pinCredentials.containsKey(cleanEmail) && !await checkRemoteHasPin(cleanEmail)) return false;
    return await setPinForUser(
      email: cleanEmail,
      pin: newPin,
      autoSignIn: false,
      isUpdate: true,
    );
  }

  /// Universal OAuth 2.0 Loopback Flow with RFC 7636 PKCE
  /// Works across Android and Windows without requiring any Android SHA-1 keystore fingerprints.
  Future<AppUser?> _authenticateWithGoogleOAuth({
    SubscriptionTier initialTier = SubscriptionTier.trial,
  }) async {
    String clientId = '';
    String clientSecret = '';
    String customRedirectUri = '';

    // 1. Direct filesystem check for .env (desktop)
    try {
      final envFile = File('.env');
      if (envFile.existsSync()) {
        final lines = envFile.readAsLinesSync();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('GOOGLE_OAUTH_CLIENT_ID=')) {
            clientId = trimmed.substring('GOOGLE_OAUTH_CLIENT_ID='.length).trim();
          } else if (trimmed.startsWith('GOOGLE_OAUTH_CLIENT_ID_WINDOWS=')) {
            clientId = trimmed.substring('GOOGLE_OAUTH_CLIENT_ID_WINDOWS='.length).trim();
          } else if (trimmed.startsWith('GOOGLE_OAUTH_CLIENT_SECRET=')) {
            clientSecret = trimmed.substring('GOOGLE_OAUTH_CLIENT_SECRET='.length).trim();
          } else if (trimmed.startsWith('GOOGLE_OAUTH_CLIENT_SECRET_WINDOWS=')) {
            clientSecret = trimmed.substring('GOOGLE_OAUTH_CLIENT_SECRET_WINDOWS='.length).trim();
          } else if (trimmed.startsWith('GOOGLE_OAUTH_REDIRECT_URI=')) {
            customRedirectUri = trimmed.substring('GOOGLE_OAUTH_REDIRECT_URI='.length).trim();
          }
        }
      }
    } catch (_) {}

    // Fallback to flutter_dotenv if present
    if (clientId.trim().isEmpty) {
      try {
        clientId = dotenv.env['GOOGLE_OAUTH_CLIENT_ID'] ?? dotenv.env['GOOGLE_OAUTH_CLIENT_ID_WINDOWS'] ?? '';
        clientSecret = dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET'] ?? dotenv.env['GOOGLE_OAUTH_CLIENT_SECRET_WINDOWS'] ?? '';
        customRedirectUri = dotenv.env['GOOGLE_OAUTH_REDIRECT_URI'] ?? '';
      } catch (_) {}
    }

    if (clientId.trim().isEmpty) {
      clientId = _defaultDesktopClientId;
      clientSecret = _defaultDesktopClientSecret;
    }

    if (clientId.trim().isEmpty) {
      clientId = webClientId.trim().isNotEmpty ? webClientId.trim() : _defaultWebClientId;
    }

    if (clientId.trim().isEmpty) {
      _errorMessage = 'Google OAuth Client ID is not configured on Windows. Please enter your email and 4-digit PIN to sign in.';
      _isLoading = false;
      _authStatusMessage = null;
      notifyListeners();
      return null;
    }

    HttpServer? server;
    try {
      // 0. Close any previous dangling OAuth server
      try {
        await _activeOAuthServer?.close(force: true);
      } catch (_) {}
      _activeOAuthServer = null;

      // 1. Generate RFC 7636 PKCE Code Verifier & Challenge
      final random = Random.secure();
      final verifierBytes = List<int>.generate(32, (_) => random.nextInt(256));
      final codeVerifier = base64UrlEncode(verifierBytes).replaceAll('=', '');
      final codeChallenge = base64UrlEncode(
        sha256.convert(ascii.encode(codeVerifier)).bytes,
      ).replaceAll('=', '');

      // 2. Start a local server to listen for the redirect.
      // Attempt fixed port 8585 first, fall back to dynamic port 0
      int targetPort = 8585;
      if (customRedirectUri.isNotEmpty) {
        final parsedUri = Uri.tryParse(customRedirectUri);
        if (parsedUri != null && parsedUri.hasPort) {
          targetPort = parsedUri.port;
        }
      }

      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, targetPort);
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      }
      _activeOAuthServer = server;

      final redirectUri = customRedirectUri.isNotEmpty
          ? customRedirectUri
          : 'http://127.0.0.1:${server.port}';

      // 3. Open browser for Google Sign-In with PKCE challenge
      final authParams = <String, String>{
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'email profile openid',
        'access_type': 'offline',
        'prompt': 'select_account',
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      };

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', authParams);

      _authStatusMessage = 'Opening system browser for Google Sign-In...';
      notifyListeners();

      bool launched = false;
      try {
        launched = await launchUrl(
          authUrl,
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        debugPrint('AuthService: launchUrl externalApplication note: $e; falling back to platformDefault');
        try {
          launched = await launchUrl(
            authUrl,
            mode: LaunchMode.platformDefault,
          );
        } catch (_) {}
      }
      if (!launched) {
        throw Exception('Could not launch system browser for Google sign-in.');
      }

      _authStatusMessage = 'Waiting for Google account selection in browser...';
      notifyListeners();

      // 4. Wait for the redirect request from the browser (120s timeout for mobile & desktop)
      final request = await server.firstWhere((req) {
        if (req.uri.queryParameters.containsKey('code') ||
            req.uri.queryParameters.containsKey('error') ||
            req.uri.path == '/' ||
            req.uri.path.isEmpty) {
          return true;
        }
        req.response.statusCode = 404;
        req.response.close();
        return false;
      }).timeout(const Duration(seconds: 120));

      _authStatusMessage = 'Google account verified! Finalizing sign-in...';
      notifyListeners();
      final code = request.uri.queryParameters['code'];

      // Send a rich branded response to the browser
      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html; charset=utf-8')
        ..write('''
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <title>JC POS System - Sign in Successful</title>
              <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                  background-color: #0E0A06;
                  color: #E6D2B5;
                  display: flex;
                  justify-content: center;
                  align-items: center;
                  min-height: 100vh;
                  padding: 20px;
                }
                .card {
                  background-color: #1A130C;
                  border: 1.5px solid #E5A93C;
                  border-radius: 20px;
                  padding: 36px 28px;
                  text-align: center;
                  box-shadow: 0 16px 40px rgba(0,0,0,0.7);
                  max-width: 420px;
                  width: 100%;
                }
                .badge {
                  width: 60px;
                  height: 60px;
                  background: rgba(229, 169, 60, 0.15);
                  border: 2px solid #E5A93C;
                  border-radius: 50%;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  margin: 0 auto 18px auto;
                  font-size: 28px;
                  color: #E5A93C;
                }
                h1 { color: #E5A93C; font-size: 22px; font-weight: 700; margin-bottom: 10px; }
                p { color: #C9B299; font-size: 14px; line-height: 1.5; margin-bottom: 22px; }
                .btn {
                  display: inline-block;
                  background: #E5A93C;
                  color: #0E0A06;
                  text-decoration: none;
                  font-weight: 700;
                  font-size: 15px;
                  padding: 13px 26px;
                  border-radius: 12px;
                  box-shadow: 0 4px 15px rgba(229, 169, 60, 0.3);
                }
                .subtext { font-size: 12px; color: #8C7A68; margin-top: 16px; }
              </style>
            </head>
            <body>
              <div class="card">
                <div class="badge">✓</div>
                <h1>Authentication Successful!</h1>
                <p>Your Google account has been verified. Return to JC POS System to continue.</p>
                <a href="jcpos://login?success=true" class="btn" id="returnBtn">
                  Return to JC POS System
                </a>
                <p class="subtext">You can close this tab if not redirected automatically.</p>
                <script>
                  function returnToApp() {
                    try {
                      window.location.href = "jcpos://login?success=true";
                    } catch(e) {}
                    setTimeout(function() {
                      try {
                        window.location.href = "intent://#Intent;scheme=jcpos;package=com.celestialcafe.celestial_pos;end";
                      } catch(e) {}
                    }, 300);
                  }
                  returnToApp();
                  setTimeout(function() {
                    try { window.close(); } catch(e) {}
                  }, 3000);
                </script>
              </div>
            </body>
          </html>
        ''');
      await request.response.close();

      if (code == null) {
        final error = request.uri.queryParameters['error'];
        final errorDesc = request.uri.queryParameters['error_description'];
        if (error != null) {
          debugPrint('AuthService: Google OAuth returned error: $error ($errorDesc)');
          _errorMessage = errorDesc ?? 'Google sign-in authorization was denied ($error).';
        }
        return null; // User cancelled or denied
      }

      // 5. Exchange code for tokens with PKCE code_verifier + optional client_secret
      final tokenBody = <String, String>{
        'client_id': clientId,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      };
      if (clientSecret.trim().isNotEmpty) {
        tokenBody['client_secret'] = clientSecret.trim();
      }

      final tokenResponse = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: tokenBody,
      );

      if (tokenResponse.statusCode != 200) {
        final errBody = tokenResponse.body;
        debugPrint('AuthService: OAuth token exchange failed: $errBody');
        throw Exception('Token exchange failed: $errBody');
      }

      final tokenData = json.decode(tokenResponse.body);
      final accessToken = tokenData['access_token'];
      final idToken = tokenData['id_token'];

      // 6. Fetch user profile info using the access token
      final profileResponse = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v2/userinfo'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (profileResponse.statusCode != 200) {
        final errBody = profileResponse.body;
        debugPrint('AuthService: Profile fetch failed - $errBody');
        throw Exception('Failed to fetch profile: $errBody');
      }

      final profileData = json.decode(profileResponse.body);

      // 7. Exchange Google ID token for genuine Firebase ID token to authorize cloud writes
      String? firebaseAuthToken;
      if (idToken != null && idToken.toString().isNotEmpty) {
        firebaseAuthToken = await exchangeGoogleIdTokenForFirebase(idToken.toString());
      }

      final email = profileData['email']?.toString() ?? 'unknown@example.com';
      final isAdminUser = checkIfAdmin(email);
      final displayName = profileData['name']?.toString() ?? email.split('@').first;
      final photoUrl = profileData['picture']?.toString();

      await rememberStationAccount(
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        isGoogle: true,
      );

      // Look up any admin-configured values for this account
      AppUser existingAccount = _managedAccounts.firstWhere(
        (a) => a.email.toLowerCase() == email.toLowerCase(),
        orElse: () => AppUser(
          uid: profileData['id']?.toString() ?? 'oauth_${email.hashCode.abs()}',
          email: email,
          displayName: displayName,
          photoUrl: photoUrl,
          tier: isAdminUser ? SubscriptionTier.pro : initialTier,
          trialStartDate: DateTime.now(),
          isAdmin: isAdminUser,
          customTrialDays: _defaultTrialDays,
        ),
      );

      // Fetch cloud license to ensure admin custom trial days / tier are synced immediately
      try {
        final remote = await _fetchUserFromRealtimeDatabase(email);
        if (remote != null) {
          final remoteDays = (remote['customTrialDays'] as num?)?.toInt();
          final remoteStart = DateTime.tryParse(remote['trialStartDate']?.toString() ?? '');
          final remoteTierStr = remote['tier']?.toString();
          final remoteIsAdmin = remote['isAdmin'] == true || isAdminUser;
          final remoteTier = (remoteTierStr == 'pro' || remoteIsAdmin) ? SubscriptionTier.pro : SubscriptionTier.trial;

          existingAccount = existingAccount.copyWith(
            customTrialDays: remoteDays ?? existingAccount.customTrialDays,
            hasCustomTrial: remote['hasCustomTrial'] == true || remoteDays != null || existingAccount.hasCustomTrial,
            trialStartDate: remoteStart ?? existingAccount.trialStartDate,
            tier: remoteTier,
            isAdmin: remoteIsAdmin,
          );
        }
      } catch (_) {}

      final isReturning = existingAccount.uid.isNotEmpty;
      final trialDays = isReturning ? existingAccount.customTrialDays : _defaultTrialDays;
      final savedTier = isReturning ? existingAccount.tier : (isAdminUser ? SubscriptionTier.pro : initialTier);
      final savedTrialStart = isReturning ? existingAccount.trialStartDate : DateTime.now();

      return AppUser(
        uid: profileData['id']?.toString() ?? existingAccount.uid,
        email: email,
        displayName: profileData['name']?.toString() ?? existingAccount.displayName,
        photoUrl: profileData['picture']?.toString() ?? existingAccount.photoUrl,
        tier: isAdminUser ? SubscriptionTier.pro : savedTier,
        trialStartDate: savedTrialStart,
        proActivatedDate: existingAccount.proActivatedDate,
        isAdmin: isAdminUser,
        customTrialDays: trialDays,
        idToken: firebaseAuthToken ?? idToken?.toString(),
      );
    } on TimeoutException {
      debugPrint('AuthService: Google Sign-In timed out or was closed by user.');
      _errorMessage = 'Google sign-in timed out. Please try again.';
      return null;
    } catch (e) {
      debugPrint('AuthService: Google OAuth error: $e');
      rethrow;
    } finally {
      _activeOAuthServer = null;
      try {
        await server?.close(force: true);
      } catch (_) {}
    }
  }

  // --- Sign In with Google / Gmail ---
  Future<GoogleAuthResult> signInWithGoogle({SubscriptionTier initialTier = SubscriptionTier.trial}) async {
    _isLoading = true;
    _errorMessage = null;
    _pendingGoogleUser = null;
    _authStatusMessage = 'Connecting to Google...';
    notifyListeners();

    try {
      // 1. Mobile (Android & iOS): Native Google Sign-In with resilient silent check & quick setup fallback
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        GoogleSignIn? googleSignIn;
        try {
          googleSignIn = _buildGoogleSignIn(withServerClientId: true);

          // Attempt fast silent sign-in first if previously authorized
          GoogleSignInAccount? account;
          try {
            account = await googleSignIn.signInSilently().timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () => null,
            );
          } catch (silentErr) {
            debugPrint('Mobile Google silent sign-in note: $silentErr');
          }

          // If no silent account found, prompt the native Google account selection dialog
          if (account == null) {
            _authStatusMessage = 'Select Google account...';
            notifyListeners();

            account = await googleSignIn.signIn().timeout(
              const Duration(seconds: 60),
              onTimeout: () => null,
            );
          }

          // Check if sign-in was cancelled while awaiting
          if (!_isLoading) {
            return GoogleAuthResult.cancelled;
          }

          if (account != null) {
            _authStatusMessage = 'Synchronizing account...';
            notifyListeners();

            final acc = account;
            GoogleSignInAuthentication? auth;
            try {
              auth = await acc.authentication;
            } catch (authErr) {
              debugPrint('Mobile Google authentication note: $authErr');
            }

            final email = acc.email;
            final isAdminUser = checkIfAdmin(email);
            await rememberStationAccount(
              email: email,
              displayName: acc.displayName,
              photoUrl: acc.photoUrl,
              isGoogle: true,
            );
            String? firebaseAuthToken;
            if (auth?.idToken != null && auth!.idToken!.isNotEmpty) {
              try {
                firebaseAuthToken = await exchangeGoogleIdTokenForFirebase(auth.idToken!);
              } catch (_) {}
            }

            AppUser existingAccount = _managedAccounts.firstWhere(
              (a) => a.email.toLowerCase() == email.toLowerCase(),
              orElse: () => AppUser(
                uid: acc.id,
                email: email,
                displayName: acc.displayName ?? email.split('@').first,
                photoUrl: acc.photoUrl,
                tier: isAdminUser ? SubscriptionTier.pro : initialTier,
                trialStartDate: DateTime.now(),
                isAdmin: isAdminUser,
                customTrialDays: _defaultTrialDays,
              ),
            );

            // Fetch latest license config from cloud RTDB
            try {
              final remote = await _fetchUserFromRealtimeDatabase(email);
              if (remote != null) {
                final remoteDays = (remote['customTrialDays'] as num?)?.toInt();
                final remoteStart = DateTime.tryParse(remote['trialStartDate']?.toString() ?? '');
                final remoteTierStr = remote['tier']?.toString();
                final remoteIsAdmin = remote['isAdmin'] == true || isAdminUser;
                final remoteTier = (remoteTierStr == 'pro' || remoteIsAdmin) ? SubscriptionTier.pro : SubscriptionTier.trial;

                existingAccount = existingAccount.copyWith(
                  customTrialDays: remoteDays ?? existingAccount.customTrialDays,
                  hasCustomTrial: remote['hasCustomTrial'] == true || remoteDays != null || existingAccount.hasCustomTrial,
                  trialStartDate: remoteStart ?? existingAccount.trialStartDate,
                  tier: remoteTier,
                  isAdmin: remoteIsAdmin,
                );
              }
            } catch (_) {}

            final isReturning = existingAccount.uid.isNotEmpty && existingAccount.uid != acc.id;
            final trialDays = isReturning ? existingAccount.customTrialDays : _defaultTrialDays;
            final savedTier = isReturning ? existingAccount.tier : (isAdminUser ? SubscriptionTier.pro : initialTier);
            final savedTrialStart = isReturning ? existingAccount.trialStartDate : DateTime.now();

            final user = AppUser(
              uid: acc.id,
              email: email,
              displayName: acc.displayName ?? (existingAccount.displayName.isNotEmpty ? existingAccount.displayName : email.split('@').first),
              photoUrl: acc.photoUrl ?? existingAccount.photoUrl,
              tier: isAdminUser ? SubscriptionTier.pro : savedTier,
              trialStartDate: savedTrialStart,
              proActivatedDate: existingAccount.proActivatedDate,
              isAdmin: isAdminUser,
              customTrialDays: trialDays,
              idToken: firebaseAuthToken ?? auth?.idToken,
            );

            _pendingGoogleUser = user;
            _isLoading = false;
            _authStatusMessage = null;
            notifyListeners();
            return GoogleAuthResult.needsPin;
          } else {
            // User cancelled or dismissed the native Google account picker dialog
            _isLoading = false;
            _authStatusMessage = null;
            notifyListeners();
            return GoogleAuthResult.cancelled;
          }
        } on PlatformException catch (pe) {
          debugPrint('Mobile Google Sign-In PlatformException: ${pe.code} - ${pe.message}');
          _isLoading = false;
          _authStatusMessage = null;
          notifyListeners();
          if (pe.code == 'sign_in_canceled' || pe.code == 'canceled') {
            return GoogleAuthResult.cancelled;
          }
          final currentAcc = googleSignIn?.currentUser;
          if (currentAcc != null && currentAcc.email.isNotEmpty) {
            final email = currentAcc.email;
            final isAdminUser = checkIfAdmin(email);
            _pendingGoogleUser = AppUser(
              uid: currentAcc.id,
              email: email,
              displayName: currentAcc.displayName ?? email.split('@').first,
              photoUrl: currentAcc.photoUrl,
              tier: isAdminUser ? SubscriptionTier.pro : initialTier,
              trialStartDate: DateTime.now(),
              isAdmin: isAdminUser,
              customTrialDays: _defaultTrialDays,
            );
            return GoogleAuthResult.needsPin;
          }
          final rawMsg = pe.message ?? '';
          if (pe.code == 'sign_in_failed' && (rawMsg.contains('10') || rawMsg.contains('ApiException: 10') || rawMsg.contains('common.api'))) {
            _errorMessage = 'Google Sign-In configuration error (Code 10: DEVELOPER_ERROR). Please add your Android SHA-1 fingerprint (AA:49:5B:1B...) to Firebase Console and update google-services.json, or sign in directly with Email & PIN.';
          } else {
            _errorMessage = pe.message ?? 'Google Sign-In was unable to complete: ${pe.code}';
          }
          return GoogleAuthResult.error;
        } catch (e) {
          debugPrint('Mobile Google Sign-In note: $e');
          _isLoading = false;
          _authStatusMessage = null;
          notifyListeners();
          final currentAcc = googleSignIn?.currentUser;
          if (currentAcc != null && currentAcc.email.isNotEmpty) {
            final email = currentAcc.email;
            final isAdminUser = checkIfAdmin(email);
            _pendingGoogleUser = AppUser(
              uid: currentAcc.id,
              email: email,
              displayName: currentAcc.displayName ?? email.split('@').first,
              photoUrl: currentAcc.photoUrl,
              tier: isAdminUser ? SubscriptionTier.pro : initialTier,
              trialStartDate: DateTime.now(),
              isAdmin: isAdminUser,
              customTrialDays: _defaultTrialDays,
            );
            return GoogleAuthResult.needsPin;
          }
          final errStr = e.toString();
          if (errStr.contains('10') && (errStr.contains('ApiException') || errStr.contains('common.api'))) {
            _errorMessage = 'Google Sign-In configuration error (Code 10: DEVELOPER_ERROR). Please add your Android SHA-1 fingerprint (AA:49:5B:1B...) to Firebase Console and update google-services.json, or sign in directly with Email & PIN.';
          } else {
            _errorMessage = errStr;
          }
          return GoogleAuthResult.error;
        }
      }

      // 2. Desktop Platforms (Windows, macOS, Linux): RFC 7636 PKCE OAuth Loopback Flow
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux)) {
        final user = await _authenticateWithGoogleOAuth(initialTier: initialTier);
        if (user == null || !_isLoading) {
          _isLoading = false;
          _authStatusMessage = null;
          notifyListeners();
          if (_errorMessage != null && _errorMessage!.isNotEmpty) {
            return GoogleAuthResult.error;
          }
          return GoogleAuthResult.cancelled;
        }

        _pendingGoogleUser = user;
        _isLoading = false;
        _authStatusMessage = null;
        notifyListeners();
        return GoogleAuthResult.needsPin;
      }

      await _ensureInitialized();

      // Web platform fallback
      final googleSignIn = _buildGoogleSignIn(withServerClientId: true);
      try {
        final googleUser = await googleSignIn.signIn();
        if (googleUser != null) {
          final email = googleUser.email;
          final isAdminUser = checkIfAdmin(email);
          final auth = await googleUser.authentication;
          final user = AppUser(
            uid: googleUser.id,
            email: email,
            displayName: googleUser.displayName ?? email.split('@').first,
            photoUrl: googleUser.photoUrl,
            tier: isAdminUser ? SubscriptionTier.pro : initialTier,
            trialStartDate: DateTime.now(),
            isAdmin: isAdminUser,
            customTrialDays: _defaultTrialDays,
            idToken: auth.idToken,
          );

          _pendingGoogleUser = user;
          _isLoading = false;
          _authStatusMessage = null;
          notifyListeners();
          return GoogleAuthResult.needsPin;
        } else {
          _isLoading = false;
          _authStatusMessage = null;
          notifyListeners();
          return GoogleAuthResult.cancelled;
        }
      } catch (e) {
        debugPrint('Google Sign-In prompt error: $e');
        final err = e.toString().toLowerCase();
        if (err.contains('popup_closed') || err.contains('closed by user')) {
          _isLoading = false;
          _authStatusMessage = null;
          notifyListeners();
          return GoogleAuthResult.cancelled;
        }
        if (kIsWeb && (err.contains('disallowed_useragent') || err.contains('blocked') || err.contains('popup_blocked'))) {
          _errorMessage = 'Google Sign-In was blocked by your browser. If you are inside Messenger or an in-app browser, tap (...) at the top and select "Open in Chrome/Safari", or sign in with your Email & PIN.';
        } else {
          _errorMessage = 'Google Sign-In could not be opened: ${e.toString().replaceAll("Exception:", "").trim()}';
        }
        _isLoading = false;
        _authStatusMessage = null;
        notifyListeners();
        return GoogleAuthResult.error;
      }
    } on PlatformException catch (pe) {
      debugPrint('Google Sign-In unhandled PlatformException: ${pe.code} - ${pe.message}');
      if (pe.code == 'sign_in_canceled' || pe.code == 'canceled') {
        _isLoading = false;
        _authStatusMessage = null;
        notifyListeners();
        return GoogleAuthResult.cancelled;
      }
      _errorMessage = 'Sign in failed: ${pe.message ?? pe.code}';
      _isLoading = false;
      _authStatusMessage = null;
      notifyListeners();
      return GoogleAuthResult.error;
    } catch (e) {
      debugPrint('Google Sign-In exception: $e');
      final cleanMsg = e.toString().replaceAll('Exception:', '').trim();
      _errorMessage = cleanMsg;
      _isLoading = false;
      _authStatusMessage = null;
      notifyListeners();
      return GoogleAuthResult.error;
    } finally {
      if (_isLoading) {
        _isLoading = false;
        _authStatusMessage = null;
        notifyListeners();
      }
    }
  }

  // --- Sign In with Custom Gmail / Email ---
  Future<bool> signInWithEmail({
    required String email,
    required String password,
    SubscriptionTier initialTier = SubscriptionTier.trial,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanEmail = email.trim();
      final isAdminUser = checkIfAdmin(cleanEmail);

      // Look up any admin-configured values for this account
      final existingAccount = _managedAccounts.firstWhere(
        (a) => a.email.toLowerCase() == cleanEmail.toLowerCase(),
        orElse: () => AppUser(
          uid: '',
          email: cleanEmail,
          displayName: '',
          trialStartDate: DateTime.now(),
          customTrialDays: _defaultTrialDays,
        ),
      );
      final isReturning = existingAccount.uid.isNotEmpty;
      // Preserve admin-assigned trial config for returning accounts;
      // new accounts use the admin default trial days.
      final trialDays = isReturning ? existingAccount.customTrialDays : _defaultTrialDays;
      final savedTier = isReturning ? existingAccount.tier : (isAdminUser ? SubscriptionTier.pro : initialTier);
      final savedTrialStart = isReturning ? existingAccount.trialStartDate : DateTime.now();

      if (_isFirebaseAvailable) {
        try {
          final cred = await fb_auth.FirebaseAuth.instance.signInWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          _currentUser = AppUser(
            uid: cred.user?.uid ?? 'uid_${DateTime.now().millisecondsSinceEpoch}',
            email: cred.user?.email ?? cleanEmail,
            displayName: cred.user?.displayName ?? cleanEmail.split('@').first,
            photoUrl: cred.user?.photoURL,
            tier: isAdminUser ? SubscriptionTier.pro : savedTier,
            trialStartDate: savedTrialStart,
            isAdmin: isAdminUser,
            customTrialDays: trialDays,
          );
        } catch (fbErr) {
          final cred = await fb_auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );
          _currentUser = AppUser(
            uid: cred.user?.uid ?? 'uid_${DateTime.now().millisecondsSinceEpoch}',
            email: cred.user?.email ?? cleanEmail,
            displayName: cleanEmail.split('@').first,
            photoUrl: cred.user?.photoURL,
            tier: isAdminUser ? SubscriptionTier.pro : savedTier,
            trialStartDate: savedTrialStart,
            isAdmin: isAdminUser,
            customTrialDays: trialDays,
          );
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 300));
        _currentUser = AppUser(
          uid: isReturning ? existingAccount.uid : 'user_${cleanEmail.hashCode.abs()}',
          email: cleanEmail,
          displayName: cleanEmail.split('@').first,
          photoUrl: null,
          tier: isAdminUser ? SubscriptionTier.pro : savedTier,
          trialStartDate: savedTrialStart,
          isAdmin: isAdminUser,
          customTrialDays: trialDays,
        );
      }

      if (_currentUser != null) {
        await _persistUser(_currentUser!);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // --- Sign In as Master Admin ---
  Future<void> signInAsAdmin({String email = 'adminpogi6@gmail.com'}) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 250));
    final cleanEmail = email.trim();
    if (!checkIfAdmin(cleanEmail)) {
      addAdminEmail(cleanEmail);
    }

    _currentUser = AppUser(
      uid: 'admin_${cleanEmail.hashCode.abs()}',
      email: cleanEmail,
      displayName: 'Master Administrator',
      photoUrl: null,
      tier: SubscriptionTier.pro,
      trialStartDate: DateTime.now().subtract(const Duration(days: 30)),
      proActivatedDate: DateTime.now().subtract(const Duration(days: 30)),
      isAdmin: true,
      customTrialDays: 999,
    );

    await _persistUser(_currentUser!);
    _isLoading = false;
    notifyListeners();
  }

  // --- Elevate Admin Session (Admin authorization required) ---
  Future<bool> verifyAdminPin(String pin) async {
    if (_currentUser == null) return false;
    final email = _currentUser!.email.trim().toLowerCase();
    if (!checkIfAdmin(email)) {
      debugPrint('[AUTH] verifyAdminPin rejected: $email is not authorized.');
      return false;
    }
    if (pin.trim() == '8888') {
      _currentUser = _currentUser!.copyWith(isAdmin: true);
      await _persistUser(_currentUser!);
      notifyListeners();
      return true;
    }
    return false;
  }

  // --- Add Admin Email (Admin only) ---
  Future<void> addAdminEmail(String email) async {
    if (!isAdmin) {
      debugPrint('[AUTH] addAdminEmail rejected: Only administrators can add admin emails.');
      return;
    }
    final clean = email.trim().toLowerCase();
    if (!_adminEmails.any((e) => e.toLowerCase() == clean)) {
      _adminEmails.add(clean);
      final prefs = await _getPrefs();
      await prefs.setStringList(_keyAdminEmails, _adminEmails);
      notifyListeners();
    }
  }

  // --- Continue with Instant Free Trial (Always uses Admin-configured default days) ---
  Future<void> continueWithTrial({String? customEmail}) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 200));
    final email = customEmail ?? 'trial.cafe@gmail.com';
    // Always use the admin-configured default trial duration
    final trialDays = _defaultTrialDays;

    _currentUser = AppUser(
      uid: 'trial_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: 'Trial Station',
      photoUrl: null,
      tier: SubscriptionTier.trial,
      trialStartDate: DateTime.now(),
      isAdmin: checkIfAdmin(email),
      customTrialDays: trialDays,
    );

    await _persistUser(_currentUser!);
    _isLoading = false;
    notifyListeners();
  }

  // --- Set Global Default Trial Days ---
  Future<void> setDefaultTrialDays(int days) async {
    if (_currentUser != null && !isAdmin) {
      debugPrint('[AUTH] setDefaultTrialDays rejected: Only administrators can configure default trial.');
      return;
    }
    _defaultTrialDays = days.clamp(1, 365);
    final prefs = await _getPrefs();
    await prefs.setInt(_keyDefaultTrialDays, _defaultTrialDays);

    // Automatically sync current user if using default trial
    if (_currentUser != null && !_currentUser!.hasCustomTrial && !_currentUser!.isAdmin) {
      _currentUser = _currentUser!.copyWith(customTrialDays: _defaultTrialDays);
      await _persistUser(_currentUser!);
    }

    // Automatically sync all managed accounts on default trial
    for (int i = 0; i < _managedAccounts.length; i++) {
      if (!_managedAccounts[i].hasCustomTrial && !_managedAccounts[i].isAdmin) {
        _managedAccounts[i] = _managedAccounts[i].copyWith(customTrialDays: _defaultTrialDays);
      }
    }
    await _persistManagedAccounts();

    notifyListeners();
  }

  // --- Manage Account: Switch Tier (Trial vs Pro - JC Celestial Admin Only) ---
  Future<void> updateAccountTier(String uid, SubscriptionTier tier) async {
    if (!isAdmin) {
      debugPrint('[AUTH] updateAccountTier rejected: Unauthorized non-admin attempt. Only JC Celestial can change account tier.');
      return;
    }
    final idx = _managedAccounts.indexWhere((a) => a.uid == uid || a.email.toLowerCase() == uid.toLowerCase());
    if (idx >= 0) {
      final account = _managedAccounts[idx];
      final isSwitchingToTrial = tier == SubscriptionTier.trial && account.tier != SubscriptionTier.trial;
      final shouldResetStart = isSwitchingToTrial && account.isTrialExpired;

      final updated = account.copyWith(
        tier: tier,
        proActivatedDate: tier == SubscriptionTier.pro ? DateTime.now() : null,
        trialStartDate: shouldResetStart ? DateTime.now() : account.trialStartDate,
      );
      _managedAccounts[idx] = updated;

      if (_currentUser != null &&
          (_currentUser!.uid == uid ||
           _currentUser!.email.toLowerCase() == updated.email.toLowerCase())) {
        _currentUser = _currentUser!.copyWith(
          tier: tier,
          proActivatedDate: updated.proActivatedDate,
          trialStartDate: updated.trialStartDate,
        );
        await _persistUser(_currentUser!);
      }

      await _persistManagedAccounts();
      notifyListeners();

      unawaited(_syncAccountTierToRealtimeDatabase(
        targetEmail: updated.email,
        tier: updated.tier.name,
        trialStartDate: updated.trialStartDate,
        proActivatedDate: updated.proActivatedDate,
      ));
    }
  }

  // --- Manage Account: Custom Input Trial Days (JC Celestial Admin Only) ---
  Future<void> updateAccountCustomTrial(
    String uid,
    int trialDays, {
    bool resetStartDate = false,
  }) async {
    if (!isAdmin) {
      debugPrint('[AUTH] updateAccountCustomTrial rejected: Only JC Celestial can configure custom trial.');
      return;
    }
    final sanitizedDays = trialDays.clamp(0, 3650);
    final idx = _managedAccounts.indexWhere((a) => a.uid == uid || a.email.toLowerCase() == uid.toLowerCase());
    if (idx >= 0) {
      final existing = _managedAccounts[idx];
      final elapsed = DateTime.now().difference(existing.trialStartDate).inDays;
      final shouldResetStart = sanitizedDays > 0 && (resetStartDate || existing.isTrialExpired || elapsed >= sanitizedDays);
      final newStartDate = sanitizedDays == 0
          ? DateTime.now().subtract(const Duration(days: 1))
          : (shouldResetStart ? DateTime.now() : existing.trialStartDate);

      final updated = existing.copyWith(
        customTrialDays: sanitizedDays,
        hasCustomTrial: true,
        trialStartDate: newStartDate,
      );
      _managedAccounts[idx] = updated;

      // Sync active session if it matches this account (by UID or Email)
      if (_currentUser != null &&
          (_currentUser!.uid == uid ||
           _currentUser!.email.toLowerCase() == updated.email.toLowerCase())) {
        _currentUser = _currentUser!.copyWith(
          customTrialDays: sanitizedDays,
          hasCustomTrial: true,
          trialStartDate: newStartDate,
          tier: updated.tier,
        );
        await _persistUser(_currentUser!);
      }

      await _persistManagedAccounts();
      notifyListeners();

      unawaited(_syncAccountTrialToRealtimeDatabase(
        targetEmail: updated.email,
        customTrialDays: sanitizedDays,
        trialStartDate: newStartDate,
        tier: updated.tier.name,
        isAdmin: updated.isAdmin,
      ));
    } else if (_currentUser != null &&
        (_currentUser!.uid == uid || _currentUser!.email.toLowerCase() == uid.toLowerCase())) {
      final shouldResetStart = sanitizedDays > 0 && (resetStartDate || _currentUser!.isTrialExpired);
      final newStartDate = sanitizedDays == 0
          ? DateTime.now().subtract(const Duration(days: 1))
          : (shouldResetStart ? DateTime.now() : _currentUser!.trialStartDate);

      _currentUser = _currentUser!.copyWith(
        customTrialDays: sanitizedDays,
        hasCustomTrial: true,
        trialStartDate: newStartDate,
      );
      _upsertManagedAccount(_currentUser!);
      await _persistUser(_currentUser!);
      await _persistManagedAccounts();
      notifyListeners();

      unawaited(_syncAccountTrialToRealtimeDatabase(
        targetEmail: _currentUser!.email,
        customTrialDays: sanitizedDays,
        trialStartDate: newStartDate,
        tier: _currentUser!.tier.name,
        isAdmin: _currentUser!.isAdmin,
      ));
    }
  }

  /// Fetches the latest trial and license details for the current user from Firebase Realtime Database.
  Future<bool> refreshUserLicenseFromCloud() async {
    if (_currentUser == null) return false;
    try {
      if (_isFlutterTest) return false;
      final remote = await _fetchUserFromRealtimeDatabase(_currentUser!.email);
      if (remote != null) {
        final remoteDays = (remote['customTrialDays'] as num?)?.toInt();
        final remoteStart = DateTime.tryParse(remote['trialStartDate']?.toString() ?? '');
        final remoteTierStr = remote['tier']?.toString();
        final remoteIsAdmin = remote['isAdmin'] == true || checkIfAdmin(_currentUser!.email);
        final remoteTier = (remoteTierStr == 'pro' || remoteIsAdmin) ? SubscriptionTier.pro : SubscriptionTier.trial;
        final remoteDisabledFeatures = (remote['disabledFeatures'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();

        _currentUser = _currentUser!.copyWith(
          customTrialDays: remoteDays ?? _currentUser!.customTrialDays,
          hasCustomTrial: remote['hasCustomTrial'] == true || remoteDays != null,
          trialStartDate: remoteStart ?? _currentUser!.trialStartDate,
          tier: remoteTier,
          isAdmin: remoteIsAdmin,
          disabledFeatures: remoteDisabledFeatures ?? _currentUser!.disabledFeatures,
        );

        _upsertManagedAccount(_currentUser!);
        await _persistUser(_currentUser!);
        await _persistManagedAccounts();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('AuthService: refreshUserLicenseFromCloud error: $e');
    }
    return false;
  }

  // --- Manage Account: Update Feature Permissions (Admin / Owner for their cashiers) ---
  Future<void> updateAccountDisabledFeatures(
    String uid,
    List<String> disabledFeatures,
  ) async {
    if (!isOwnerOrAdmin) {
      debugPrint('[AUTH] updateAccountDisabledFeatures rejected: Only store owners or administrators can configure feature permissions.');
      return;
    }
    final cleanList = List<String>.unmodifiable(disabledFeatures);
    final idx = _managedAccounts.indexWhere(
      (a) => a.uid == uid || a.email.toLowerCase() == uid.toLowerCase(),
    );
    if (!isAdmin && idx >= 0) {
      final target = _managedAccounts[idx];
      final currentOwnerEmail = _currentUser?.email.toLowerCase();
      if (!target.isCashier || target.ownerEmail?.toLowerCase() != currentOwnerEmail) {
        debugPrint('[AUTH] updateAccountDisabledFeatures rejected: Cannot modify features of another store or admin.');
        return;
      }
    }
    if (idx >= 0) {
      final existing = _managedAccounts[idx];
      final updated = existing.copyWith(disabledFeatures: cleanList);
      _managedAccounts[idx] = updated;

      // Sync active session if this account is currently logged in
      if (_currentUser != null &&
          (_currentUser!.uid == uid ||
           _currentUser!.email.toLowerCase() == updated.email.toLowerCase())) {
        _currentUser = _currentUser!.copyWith(disabledFeatures: cleanList);
        await _persistUser(_currentUser!);
      }

      await _persistManagedAccounts();
      notifyListeners();

      unawaited(_syncAccountFeaturesToRealtimeDatabase(
        targetEmail: updated.email,
        disabledFeatures: cleanList,
      ));
    } else if (_currentUser != null &&
        (_currentUser!.uid == uid || _currentUser!.email.toLowerCase() == uid.toLowerCase())) {
      _currentUser = _currentUser!.copyWith(disabledFeatures: cleanList);
      _upsertManagedAccount(_currentUser!);
      await _persistUser(_currentUser!);
      await _persistManagedAccounts();
      notifyListeners();

      unawaited(_syncAccountFeaturesToRealtimeDatabase(
        targetEmail: _currentUser!.email,
        disabledFeatures: cleanList,
      ));
    }
  }

  // --- Manage Account: Grant Extra Trial Days (JC Celestial Admin Only) ---
  Future<void> grantExtraTrialDays(String uid, int additionalDays) async {
    if (!isAdmin) {
      debugPrint('[AUTH] grantExtraTrialDays rejected: Only authorized administrators (JC Celestial) can grant extra trial days.');
      return;
    }
    final idx = _managedAccounts.indexWhere((a) => a.uid == uid || a.email.toLowerCase() == uid.toLowerCase());
    if (idx >= 0) {
      final account = _managedAccounts[idx];
      if (account.isTrialExpired) {
        await updateAccountCustomTrial(uid, additionalDays, resetStartDate: true);
      } else {
        final currentDays = account.effectiveTrialDays(_defaultTrialDays);
        final newDays = (currentDays + additionalDays).clamp(1, 3650);
        await updateAccountCustomTrial(uid, newDays, resetStartDate: false);
      }
    }
  }

  // --- Sync All Accounts From Firebase Realtime Database (/users.json) ---
  Future<bool> syncManagedAccountsFromCloud() async {
    if (_isSyncingCloudAccounts) return false;
    _isSyncingCloudAccounts = true;
    notifyListeners();

    try {
      if (_isFlutterTest) {
        _isSyncingCloudAccounts = false;
        notifyListeners();
        return false;
      }

      String? authToken = _cachedFirebaseToken;
      final queryParam = (authToken != null && authToken.isNotEmpty) ? '?auth=$authToken' : '';
      var rtdbUri = Uri.parse('$realtimeDbUrl/users.json$queryParam');

      var res = await http.get(rtdbUri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        rtdbUri = Uri.parse('$realtimeDbUrl/users.json');
        res = await http.get(rtdbUri).timeout(const Duration(seconds: 6));
      }

      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final dynamic raw = jsonDecode(res.body);
        if (raw is Map<String, dynamic>) {
          for (final entry in raw.entries) {
            final val = entry.value;
            if (val is! Map) continue;

            final rawEmail = val['email']?.toString() ?? entry.key.replaceAll(',', '.');
            final cleanEmail = rawEmail.trim().toLowerCase();
            if (cleanEmail.isEmpty) continue;

            final isAdminUser = val['isAdmin'] == true || checkIfAdmin(cleanEmail);
            final tierStr = val['tier']?.toString().toLowerCase();
            final tier = (tierStr == 'pro' || isAdminUser) ? SubscriptionTier.pro : SubscriptionTier.trial;

            final rawName = val['displayName']?.toString().trim();
            final photoUrl = val['photoUrl']?.toString();
            final customDays = (val['customTrialDays'] as num?)?.toInt() ?? _defaultTrialDays;
            final hasCustomTrial = val['hasCustomTrial'] == true || val['customTrialDays'] != null;
            final trialStartDate = DateTime.tryParse(val['trialStartDate']?.toString() ?? '') ?? DateTime.now();
            final proActivatedDate = DateTime.tryParse(val['proActivatedDate']?.toString() ?? '');
            final uid = val['uid']?.toString() ?? 'cloud_${cleanEmail.hashCode.abs()}';
            final disabledFeatures = (val['disabledFeatures'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const <String>[];

            final existingIdx = _managedAccounts.indexWhere(
              (a) => a.uid == uid || a.email.trim().toLowerCase() == cleanEmail,
            );

            final existing = existingIdx >= 0 ? _managedAccounts[existingIdx] : null;

            final effectiveName = (rawName != null && rawName.isNotEmpty)
                ? rawName
                : (existing != null && existing.displayName.isNotEmpty
                    ? existing.displayName
                    : cleanEmail.split('@').first);

            final cloudAccount = AppUser(
              uid: (existing != null && existing.uid.isNotEmpty) ? existing.uid : uid,
              email: cleanEmail,
              displayName: effectiveName,
              photoUrl: photoUrl ?? existing?.photoUrl,
              tier: tier,
              trialStartDate: trialStartDate,
              proActivatedDate: proActivatedDate ?? (tier == SubscriptionTier.pro ? DateTime.now() : null),
              isAdmin: isAdminUser,
              customTrialDays: customDays,
              hasCustomTrial: hasCustomTrial,
              disabledFeatures: disabledFeatures.isNotEmpty
                  ? disabledFeatures
                  : (existing?.disabledFeatures ?? const []),
            );

            if (existingIdx >= 0) {
              _managedAccounts[existingIdx] = cloudAccount;
            } else {
              _managedAccounts.add(cloudAccount);
            }

            // Also keep PIN credential cache up to date if pin is available in RTDB
            final remotePin = val['pin']?.toString().trim();
            if (remotePin != null && remotePin.length == 4 && !_pinCredentials.containsKey(cleanEmail)) {
              _pinCredentials[cleanEmail] = _hashPin(cleanEmail, remotePin);
            }

            // If this matches the current active user, sync current user fields
            if (_currentUser != null &&
                (_currentUser!.uid == uid || _currentUser!.email.toLowerCase() == cleanEmail)) {
              _currentUser = _currentUser!.copyWith(
                displayName: cloudAccount.displayName,
                photoUrl: cloudAccount.photoUrl ?? _currentUser!.photoUrl,
                tier: cloudAccount.tier,
                isAdmin: cloudAccount.isAdmin,
                customTrialDays: cloudAccount.customTrialDays,
                hasCustomTrial: cloudAccount.hasCustomTrial,
                trialStartDate: cloudAccount.trialStartDate,
                proActivatedDate: cloudAccount.proActivatedDate ?? _currentUser!.proActivatedDate,
                disabledFeatures: cloudAccount.disabledFeatures,
              );
              await _persistUser(_currentUser!);
            }
          }

          await _persistManagedAccounts();
          await _persistPinCredentials();
          _isSyncingCloudAccounts = false;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('AuthService: syncManagedAccountsFromCloud error: $e');
    }

    _isSyncingCloudAccounts = false;
    notifyListeners();
    return false;
  }

  // --- Manage Account: Add New Managed Station / Account (JC Celestial Admin Only) ---
  Future<void> addManagedAccount({
    required String email,
    required String displayName,
    required SubscriptionTier tier,
    int? trialDays,
  }) async {
    if (!isAdmin) {
      debugPrint('[AUTH] addManagedAccount rejected: Only authorized administrators (JC Celestial) can add station accounts.');
      return;
    }
    final cleanEmail = email.trim();
    final isExplicitCustom = trialDays != null;
    final days = trialDays ?? _defaultTrialDays;
    final isAdminUser = checkIfAdmin(cleanEmail);

    final newAcc = AppUser(
      uid: 'station_${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      displayName: displayName.trim().isEmpty ? cleanEmail.split('@').first : displayName.trim(),
      photoUrl: null,
      tier: tier,
      trialStartDate: DateTime.now(),
      proActivatedDate: tier == SubscriptionTier.pro ? DateTime.now() : null,
      isAdmin: isAdminUser,
      customTrialDays: days,
      hasCustomTrial: isExplicitCustom,
    );

    final existingIdx = _managedAccounts.indexWhere(
      (a) => a.email.toLowerCase() == cleanEmail.toLowerCase(),
    );
    if (existingIdx >= 0) {
      _managedAccounts[existingIdx] = newAcc;
    } else {
      _managedAccounts.add(newAcc);
    }
    await _persistManagedAccounts();

    if (_currentUser != null && _currentUser!.email.toLowerCase() == cleanEmail.toLowerCase()) {
      _currentUser = _currentUser!.copyWith(
        displayName: newAcc.displayName,
        tier: newAcc.tier,
        customTrialDays: newAcc.customTrialDays,
        hasCustomTrial: newAcc.hasCustomTrial,
        trialStartDate: newAcc.trialStartDate,
      );
      await _persistUser(_currentUser!);
    }

    notifyListeners();

    // Sync station to Firebase Realtime Database
    unawaited(_syncUserWithFirebase(
      cleanEmail,
      '1234',
      displayName: newAcc.displayName,
      isAdmin: isAdminUser,
      tier: newAcc.tier.name,
      customTrialDays: newAcc.customTrialDays,
    ));
  }

  // --- Manage Account: Delete Account (JC Celestial Admin Only) ---
  Future<void> deleteManagedAccount(String uid) async {
    if (!isAdmin) {
      debugPrint('[AUTH] deleteManagedAccount rejected: Only authorized administrators (JC Celestial) can delete station accounts.');
      return;
    }
    final idx = _managedAccounts.indexWhere((a) => a.uid == uid || a.email.toLowerCase() == uid.toLowerCase());
    String? emailToDelete;
    if (idx >= 0) {
      emailToDelete = _managedAccounts[idx].email;
      _managedAccounts.removeAt(idx);
    } else {
      _managedAccounts.removeWhere((a) => a.uid == uid);
    }
    await _persistManagedAccounts();
    notifyListeners();

    if (emailToDelete != null && emailToDelete.isNotEmpty) {
      unawaited(_deleteUserFromRealtimeDatabase(emailToDelete));
    }
  }

  // --- Store Owner: Create Cashier / Staff Account with Custom Email & 4-Digit PIN ---
  Future<bool> createCashierAccount({
    required String email,
    required String displayName,
    required String pin,
    UserRole role = UserRole.cashier,
    String? customRoleTitle,
    List<String>? disabledFeatures,
  }) async {
    if (!isOwnerOrAdmin) {
      debugPrint('[AUTH] createCashierAccount rejected: Only store owners or admins can create cashier accounts.');
      _errorMessage = 'Store Owner privileges required to create cashiers.';
      notifyListeners();
      return false;
    }
    String cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      if (displayName.trim().isNotEmpty) {
        cleanEmail = '${displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_')}@celestial.local';
      } else {
        _errorMessage = 'Please enter a valid cashier name, username, or email.';
        notifyListeners();
        return false;
      }
    } else if (!cleanEmail.contains('@')) {
      cleanEmail = '${cleanEmail.replaceAll(' ', '_')}@celestial.local';
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      _errorMessage = 'PIN must be exactly 4 numeric digits.';
      notifyListeners();
      return false;
    }

    if (checkIfAdmin(cleanEmail)) {
      _errorMessage = 'Cannot register an administrator email as a cashier station.';
      notifyListeners();
      return false;
    }

    final currentOwnerEmail = _currentUser?.email.toLowerCase() ?? '';

    // Standard Cashier Only restrictions: cannot modify menu, stock, settings, or view costing/analytics
    final featuresToLock = disabledFeatures ?? const [
      'food_costing',
      'analytics',
      'store_settings',
      'inventory',
    ];

    // Register PIN in local credentials
    _pinCredentials[cleanEmail] = _hashPin(cleanEmail, pin);
    await _persistPinCredentials();

    final cleanRoleTitle = (customRoleTitle != null && customRoleTitle.trim().isNotEmpty)
        ? customRoleTitle.trim().toUpperCase()
        : (role == UserRole.cashier ? 'CASHIER' : role.label);

    final cleanDisplayName = displayName.trim().isNotEmpty
        ? displayName.trim()
        : cleanEmail.split('@').first.replaceAll('_', ' ');

    final newCashier = AppUser(
      uid: 'cashier_${DateTime.now().millisecondsSinceEpoch}',
      email: cleanEmail,
      displayName: cleanDisplayName,
      tier: SubscriptionTier.pro, // Covered by Store Owner's Pro license
      trialStartDate: DateTime.now(),
      isAdmin: false,
      role: role,
      customRoleTitle: cleanRoleTitle,
      ownerEmail: currentOwnerEmail,
      disabledFeatures: featuresToLock,
    );

    final existingIdx = _managedAccounts.indexWhere(
      (a) => a.email.toLowerCase() == cleanEmail,
    );
    if (existingIdx >= 0) {
      _managedAccounts[existingIdx] = newCashier;
    } else {
      _managedAccounts.add(newCashier);
    }
    await _persistManagedAccounts();
    notifyListeners();

    // Synchronize to Firebase Realtime Database
    unawaited(_syncUserWithFirebase(
      cleanEmail,
      pin,
      displayName: newCashier.displayName,
      isAdmin: false,
      tier: 'pro',
    ));
    unawaited(_syncAccountFeaturesToRealtimeDatabase(
      targetEmail: cleanEmail,
      disabledFeatures: featuresToLock,
    ));

    return true;
  }

  // --- Store Owner: Update Cashier / Staff Station Role ---
  Future<bool> updateCashierRole({
    required String email,
    required UserRole newRole,
    String? customRoleTitle,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final idx = _managedAccounts.indexWhere((a) => a.email.toLowerCase() == cleanEmail);
    if (idx >= 0) {
      final cleanRoleTitle = (customRoleTitle != null && customRoleTitle.trim().isNotEmpty)
          ? customRoleTitle.trim().toUpperCase()
          : (newRole == UserRole.cashier ? 'CASHIER' : newRole.label);
      _managedAccounts[idx] = _managedAccounts[idx].copyWith(
        role: newRole,
        customRoleTitle: cleanRoleTitle,
      );
      if (_currentUser?.email.toLowerCase() == cleanEmail) {
        _currentUser = _currentUser?.copyWith(
          role: newRole,
          customRoleTitle: cleanRoleTitle,
        );
      }
      await _persistManagedAccounts();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Finds a cashier account matching an identifier (Cashier Name / DisplayName, Station Label, Username, or Email).
  AppUser? findCashierByIdentifier(String identifier) {
    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final cashiers = _managedAccounts.where((a) => a.isCashier).toList();

    // 1. Exact match by email
    for (final acc in cashiers) {
      if (acc.email.toLowerCase() == clean) return acc;
    }
    // 2. Exact match by cashier displayName (Cashier Name)
    for (final acc in cashiers) {
      if (acc.displayName.trim().toLowerCase() == clean) return acc;
    }
    // 3. Exact match by station label / roleBadgeLabel / customRoleTitle
    for (final acc in cashiers) {
      if (acc.roleBadgeLabel.trim().toLowerCase() == clean ||
          (acc.customRoleTitle != null && acc.customRoleTitle!.trim().toLowerCase() == clean)) {
        return acc;
      }
    }
    // 4. Exact match by username (portion before @ in email)
    for (final acc in cashiers) {
      if (acc.email.split('@').first.toLowerCase() == clean) return acc;
    }
    // 5. Partial / contains match if unique
    final matches = cashiers.where((a) =>
        a.displayName.toLowerCase().contains(clean) ||
        a.email.toLowerCase().contains(clean) ||
        a.roleBadgeLabel.toLowerCase().contains(clean)).toList();
    if (matches.length == 1) return matches.first;

    return null;
  }

  /// Sign in as staff using either Cashier Name or Email and 4-digit PIN
  Future<bool> signInStaff({
    required String nameOrEmail,
    required String pin,
  }) async {
    return await signInWithPin(email: nameOrEmail, pin: pin);
  }

  /// Returns only the cashier stations belonging to this store owner (enforcing multi-owner separation).
  List<AppUser> getCashiersForCurrentOwner() {
    if (_currentUser == null) return [];
    if (isAdmin) {
      return _managedAccounts.where((a) => a.isCashier).toList();
    }
    final ownerEmail = _currentUser!.email.toLowerCase();
    return _managedAccounts.where(
      (a) => a.isCashier && (a.ownerEmail?.toLowerCase() == ownerEmail),
    ).toList();
  }

  /// Returns cashier stations for a specific owner email.
  List<AppUser> getCashiersForOwner(String ownerEmail) {
    final clean = ownerEmail.trim().toLowerCase();
    return _managedAccounts.where(
      (a) => a.isCashier && (a.ownerEmail?.toLowerCase() == clean),
    ).toList();
  }

  /// Store Owner: Update or reset 4-digit PIN for a cashier station.
  Future<bool> updateCashierPin({
    required String email,
    required String newPin,
  }) async {
    if (!isOwnerOrAdmin) return false;
    final cleanEmail = email.trim().toLowerCase();
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      _errorMessage = 'PIN must be exactly 4 numeric digits.';
      notifyListeners();
      return false;
    }

    if (!isAdmin) {
      final currentOwnerEmail = _currentUser?.email.toLowerCase() ?? '';
      final isMyCashier = _managedAccounts.any(
        (a) => a.email.toLowerCase() == cleanEmail && a.isCashier && a.ownerEmail?.toLowerCase() == currentOwnerEmail,
      );
      if (!isMyCashier) {
        debugPrint('[AUTH] updateCashierPin rejected: Unauthorized access to another store\'s cashier.');
        return false;
      }
    }

    _pinCredentials[cleanEmail] = _hashPin(cleanEmail, newPin);
    await _persistPinCredentials();

    final cashier = _managedAccounts.firstWhere(
      (a) => a.email.toLowerCase() == cleanEmail,
      orElse: () => AppUser(uid: '', email: cleanEmail, displayName: cleanEmail, trialStartDate: DateTime.now()),
    );
    unawaited(_syncUserWithFirebase(
      cleanEmail,
      newPin,
      displayName: cashier.displayName,
      isAdmin: false,
      tier: 'pro',
    ));
    notifyListeners();
    return true;
  }

  /// Store Owner: Remove a cashier station.
  Future<bool> deleteCashierAccount(String emailOrUid) async {
    if (!isOwnerOrAdmin) return false;
    final clean = emailOrUid.trim().toLowerCase();
    final idx = _managedAccounts.indexWhere(
      (a) => a.uid.toLowerCase() == clean || a.email.toLowerCase() == clean,
    );
    if (idx < 0) return false;

    final target = _managedAccounts[idx];
    if (target.isAdmin) return false;

    if (!isAdmin) {
      final currentOwnerEmail = _currentUser?.email.toLowerCase() ?? '';
      if (!target.isCashier || target.ownerEmail?.toLowerCase() != currentOwnerEmail) {
        debugPrint('[AUTH] deleteCashierAccount rejected: Cannot delete cashier belonging to another store.');
        return false;
      }
    }

    final emailToDelete = target.email;
    _managedAccounts.removeAt(idx);
    _pinCredentials.remove(emailToDelete.toLowerCase());
    await _persistManagedAccounts();
    await _persistPinCredentials();
    notifyListeners();

    unawaited(_deleteUserFromRealtimeDatabase(emailToDelete));
    return true;
  }

  // --- Upgrade Current User to Pro Tier (JC Celestial Admin Only) ---
  Future<bool> upgradeToPro() async {
    if (_currentUser == null || !isAdmin) {
      debugPrint('[AUTH] upgradeToPro rejected: Only authorized store administrators (JC Celestial) can grant Pro licenses.');
      return false;
    }
    _currentUser = _currentUser!.copyWith(
      tier: SubscriptionTier.pro,
      proActivatedDate: DateTime.now(),
    );
    await _persistUser(_currentUser!);
    notifyListeners();
    return true;
  }

  // --- Toggle Tier (For Admin only) ---
  Future<bool> toggleTier() async {
    if (_currentUser == null || !isAdmin) {
      debugPrint('[AUTH] toggleTier rejected: Only authorized store administrators (JC Celestial) can toggle license tier.');
      return false;
    }
    final newTier = _currentUser!.tier == SubscriptionTier.pro
        ? SubscriptionTier.trial
        : SubscriptionTier.pro;
    _currentUser = _currentUser!.copyWith(
      tier: newTier,
      customTrialDays: newTier == SubscriptionTier.trial ? _defaultTrialDays : _currentUser!.customTrialDays,
      hasCustomTrial: newTier == SubscriptionTier.trial ? false : _currentUser!.hasCustomTrial,
      trialStartDate: newTier == SubscriptionTier.trial ? DateTime.now() : _currentUser!.trialStartDate,
    );
    await _persistUser(_currentUser!);
    notifyListeners();
    return true;
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    _cachedFirebaseToken = null;
    _cachedFirebaseTokenExpiry = null;

    try {
      if (_isFirebaseAvailable) {
        await fb_auth.FirebaseAuth.instance.signOut().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      }
    } catch (e) {
      debugPrint('Sign-out note (Firebase): $e');
    }

    try {
      if (!_isFlutterTest && (kIsWeb || (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS))) {
        final googleSignIn = _buildGoogleSignIn(withServerClientId: false);
        final signedIn = await googleSignIn.isSignedIn().timeout(const Duration(milliseconds: 1200), onTimeout: () => false);
        if (signedIn) {
          await googleSignIn.signOut().timeout(const Duration(milliseconds: 1200), onTimeout: () => null);
        }
      }
    } catch (e) {
      debugPrint('Sign-out note (Google): $e');
    }

    try {
      await _clearSecureStorage();
    } catch (e) {
      debugPrint('Sign-out note (SecureStorage): $e');
    }

    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_keyIsLoggedIn, false);
      await prefs.remove(_keyUserUid);
      await prefs.remove(_keyUserEmail);
      await prefs.remove(_keyUserName);
      await prefs.remove(_keyUserPhoto);
      await prefs.remove(_keyUserTier);
      await prefs.remove(_keyTrialStart);
      await prefs.remove(_keyIsAdmin);
      await prefs.remove(_keyCustomTrialDays);
      await prefs.remove(_prefsUserKey);
    } catch (e) {
      debugPrint('Error clearing session preferences: $e');
    }

    try {
      stopCloudLicenseSyncTimer();
    } catch (_) {}

    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }
}
