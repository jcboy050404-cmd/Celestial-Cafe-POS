import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/order.dart';

/// Configuration and branding for an individual store's online ordering portal.
class OnlineStoreProfile {
  final String storeId;
  final String ownerEmail;
  String? customSlug;
  String storeName;
  String storeTagline;
  String storeAddress;
  String storePhone;
  bool isOpen;
  bool allowDineIn;
  bool allowTakeaway;
  bool allowDelivery;
  int estimatedPrepMinutes;
  String currencySymbol;
  String? customNotice;

  OnlineStoreProfile({
    required this.storeId,
    required this.ownerEmail,
    this.customSlug,
    this.storeName = 'Celestial Cafe',
    this.storeTagline = 'Handcrafted Coffee & Treats',
    this.storeAddress = '',
    this.storePhone = '',
    this.isOpen = true,
    this.allowDineIn = true,
    this.allowTakeaway = true,
    this.allowDelivery = true,
    this.estimatedPrepMinutes = 15,
    this.currencySymbol = '₱',
    this.customNotice,
  });

  Map<String, dynamic> toJson() => {
        'storeId': storeId,
        'ownerEmail': ownerEmail,
        'customSlug': customSlug,
        'storeName': storeName,
        'storeTagline': storeTagline,
        'storeAddress': storeAddress,
        'storePhone': storePhone,
        'isOpen': isOpen,
        'allowDineIn': allowDineIn,
        'allowTakeaway': allowTakeaway,
        'allowDelivery': allowDelivery,
        'estimatedPrepMinutes': estimatedPrepMinutes,
        'currencySymbol': currencySymbol,
        'customNotice': customNotice,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory OnlineStoreProfile.fromJson(Map<String, dynamic> json) {
    return OnlineStoreProfile(
      storeId: json['storeId'] as String? ?? '',
      ownerEmail: json['ownerEmail'] as String? ?? '',
      customSlug: json['customSlug'] as String?,
      storeName: json['storeName'] as String? ?? 'Celestial Cafe',
      storeTagline: json['storeTagline'] as String? ?? 'Handcrafted Coffee & Treats',
      storeAddress: json['storeAddress'] as String? ?? '',
      storePhone: json['storePhone'] as String? ?? '',
      isOpen: json['isOpen'] as bool? ?? true,
      allowDineIn: json['allowDineIn'] as bool? ?? true,
      allowTakeaway: json['allowTakeaway'] as bool? ?? true,
      allowDelivery: json['allowDelivery'] as bool? ?? true,
      estimatedPrepMinutes: (json['estimatedPrepMinutes'] as num?)?.toInt() ?? 15,
      currencySymbol: json['currencySymbol'] as String? ?? '₱',
      customNotice: json['customNotice'] as String?,
    );
  }
}

/// Service handling multi-tenant cloud operations for customer web ordering.
///
/// Guaranteed strict isolation:
/// Each store owner's data is stored under `/online_stores/{storeId}/` in Firebase Realtime Database.
class OnlineOrderService {
  static final OnlineOrderService _instance = OnlineOrderService._internal();
  factory OnlineOrderService() => _instance;
  OnlineOrderService._internal();

  static const String _rtdbUrl =
      'https://celestial-cafe-pos-2026-default-rtdb.asia-southeast1.firebasedatabase.app';

  // In-memory cache for fast access & testing mock support
  final Map<String, OnlineStoreProfile> _localProfiles = {};
  final Map<String, List<MenuItem>> _mockStoreMenus = {};
  final Map<String, List<Order>> _mockStoreOrders = {};
  final Map<String, String> _mockStoreSlugs = {};
  final Map<String, String> _slugToStoreIdCache = {};

  bool? mockModeOverride;

  bool get _isFlutterTest {
    if (mockModeOverride != null) return mockModeOverride!;
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Converts an owner email into a deterministic, URL-safe store identifier.
  /// Example: 'owner@celestialcafe.com' -> 'owner_celestialcafe_com'
  static String getStoreId(String email) {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty) return 'default_store';
    return clean.replaceAll('@', '_at_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  /// Cleans and formats a string into a URL-safe custom slug (e.g. "Neil's Cafe" -> "neils-cafe").
  static String slugify(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r"['’]"), '');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'^-+|-+$'), '');
    return s;
  }

  /// Validates syntax of custom slug. Returns error message if invalid, or null if valid.
  static String? validateCustomSlug(String slug) {
    final clean = slugify(slug);
    if (clean.length < 3) {
      return 'Custom link must be at least 3 characters.';
    }
    if (clean.length > 40) {
      return 'Custom link cannot exceed 40 characters.';
    }
    const reserved = {'order', 'orders', 'api', 'admin', 'login', 'pos', 'default_store', 'null', 'undefined', 'app'};
    if (reserved.contains(clean)) {
      return '"$clean" is a reserved word. Please choose another link.';
    }
    return null;
  }

  /// Checks whether a custom slug is available for this owner.
  Future<({bool available, String message})> checkSlugAvailability({
    required String slug,
    required String ownerEmail,
  }) async {
    final clean = slugify(slug);
    final syntaxErr = validateCustomSlug(clean);
    if (syntaxErr != null) {
      return (available: false, message: syntaxErr);
    }

    final myStoreId = getStoreId(ownerEmail);

    if (_isFlutterTest) {
      if (_mockStoreSlugs.containsKey(clean)) {
        final existingStoreId = _mockStoreSlugs[clean];
        if (existingStoreId == myStoreId) {
          return (available: true, message: 'This is your current custom link.');
        } else {
          return (available: false, message: 'Link "$clean" is already taken by another store.');
        }
      }
      return (available: true, message: 'Link is available!');
    }

    try {
      final uri = Uri.parse('$_rtdbUrl/store_slugs/$clean.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && res.body != 'null') {
        final dynamic data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final claimedEmail = data['ownerEmail'] as String? ?? '';
          final claimedStoreId = data['storeId'] as String? ?? '';
          if (claimedEmail.toLowerCase() == ownerEmail.trim().toLowerCase() || claimedStoreId == myStoreId) {
            return (available: true, message: 'This is your current custom link.');
          }
        }
        return (available: false, message: 'Link "$clean" is already taken by another store.');
      }
      return (available: true, message: 'Link is available!');
    } catch (e) {
      return (available: true, message: 'Link format is valid.');
    }
  }

  /// Registers a custom slug mapping to a store in Firebase RTDB.
  Future<bool> claimCustomSlug({
    required String slug,
    required String storeId,
    required String ownerEmail,
  }) async {
    final clean = slugify(slug);
    if (clean.isEmpty) return false;

    _slugToStoreIdCache[clean] = storeId;
    if (_isFlutterTest) {
      _mockStoreSlugs[clean] = storeId;
      return true;
    }

    try {
      final uri = Uri.parse('$_rtdbUrl/store_slugs/$clean.json');
      final body = jsonEncode({
        'storeId': storeId,
        'ownerEmail': ownerEmail,
        'customSlug': clean,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      final res = await http.put(uri, body: body).timeout(const Duration(seconds: 8));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      if (kDebugMode) print('claimCustomSlug error: $e');
      return false;
    }
  }

  /// Releases a custom slug if an owner changes or removes it.
  Future<void> releaseCustomSlug(String oldSlug) async {
    final clean = slugify(oldSlug);
    if (clean.isEmpty) return;
    _slugToStoreIdCache.remove(clean);
    if (_isFlutterTest) {
      _mockStoreSlugs.remove(clean);
      return;
    }
    try {
      final uri = Uri.parse('$_rtdbUrl/store_slugs/$clean.json');
      await http.delete(uri).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Resolves any custom slug (or storeId) to the primary storeId for backend queries.
  Future<String> resolveStoreId(String inputKey) async {
    final rawKey = inputKey.trim();
    if (rawKey.isEmpty || rawKey == 'default_store') return 'default_store';

    // 1. In-memory cache
    if (_slugToStoreIdCache.containsKey(rawKey)) {
      return _slugToStoreIdCache[rawKey]!;
    }
    final cleanKey = slugify(rawKey);
    if (_slugToStoreIdCache.containsKey(cleanKey)) {
      return _slugToStoreIdCache[cleanKey]!;
    }

    // 2. Check local profiles
    for (final profile in _localProfiles.values) {
      if (profile.customSlug != null && (profile.customSlug == rawKey || slugify(profile.customSlug!) == cleanKey)) {
        _slugToStoreIdCache[rawKey] = profile.storeId;
        _slugToStoreIdCache[cleanKey] = profile.storeId;
        return profile.storeId;
      }
    }

    // 3. Mock test registry
    if (_isFlutterTest) {
      if (_mockStoreSlugs.containsKey(rawKey)) {
        return _mockStoreSlugs[rawKey]!;
      }
      if (_mockStoreSlugs.containsKey(cleanKey)) {
        return _mockStoreSlugs[cleanKey]!;
      }
      return rawKey;
    }

    // 4. Query Firebase RTDB /store_slugs/{cleanKey}.json
    try {
      final uri = Uri.parse('$_rtdbUrl/store_slugs/$cleanKey.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200 && res.body != 'null') {
        final dynamic data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          final targetStoreId = data['storeId'] as String?;
          if (targetStoreId != null && targetStoreId.isNotEmpty) {
            _slugToStoreIdCache[rawKey] = targetStoreId;
            _slugToStoreIdCache[cleanKey] = targetStoreId;
            return targetStoreId;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('resolveStoreId error: $e');
    }

    return rawKey;
  }

  /// Public base URL for customer web ordering.
  /// Dynamically detects current web host if running in a web browser,
  /// or defaults to the live deployed Firebase Hosting site: https://jc-pos-system.web.app
  static String get defaultBaseUrl {
    if (kIsWeb) {
      try {
        final origin = Uri.base.origin;
        if (origin.isNotEmpty && !origin.startsWith('file://')) {
          return origin;
        }
      } catch (_) {}
    }
    return 'https://jc-pos-system.web.app';
  }

  /// Constructs the public customer web ordering URL for a given store.
  static String getOrderingUrl({
    required String storeId,
    String? customSlug,
    String? tableNumber,
    String? baseUrl,
  }) {
    final domain = (baseUrl != null && baseUrl.trim().isNotEmpty)
        ? baseUrl.trim().replaceAll(RegExp(r'/+$'), '')
        : defaultBaseUrl;
    final identifier = (customSlug != null && customSlug.trim().isNotEmpty)
        ? slugify(customSlug)
        : storeId;
    final buffer = StringBuffer('$domain/#/order?store=$identifier');
    if (tableNumber != null && tableNumber.trim().isNotEmpty) {
      buffer.write('&table=${Uri.encodeComponent(tableNumber.trim())}');
    }
    return buffer.toString();
  }

  /// Publishes the store profile & active menu to Firebase so customers can order from anywhere.
  Future<bool> publishStoreCatalog({
    required OnlineStoreProfile profile,
    required List<MenuItem> menuItems,
  }) async {
    _localProfiles[profile.storeId] = profile;
    await saveLocalProfile(profile);

    if (profile.customSlug != null && profile.customSlug!.isNotEmpty) {
      await claimCustomSlug(
        slug: profile.customSlug!,
        storeId: profile.storeId,
        ownerEmail: profile.ownerEmail,
      );
    }

    if (_isFlutterTest) {
      _mockStoreMenus[profile.storeId] = List.from(menuItems);
      if (profile.customSlug != null && profile.customSlug!.isNotEmpty) {
        _mockStoreSlugs[slugify(profile.customSlug!)] = profile.storeId;
      }
      return true;
    }

    try {
      final storeId = profile.storeId;
      final profileUri = Uri.parse('$_rtdbUrl/online_stores/$storeId/profile.json');
      final menuUri = Uri.parse('$_rtdbUrl/online_stores/$storeId/menu.json');

      final profileJson = jsonEncode(profile.toJson());
      final menuJson = jsonEncode(menuItems.map((m) => m.toJson()).toList());

      final results = await Future.wait([
        http.put(profileUri, body: profileJson).timeout(const Duration(seconds: 10)),
        http.put(menuUri, body: menuJson).timeout(const Duration(seconds: 10)),
      ]);

      return results.every((r) => r.statusCode >= 200 && r.statusCode < 300);
    } catch (e) {
      if (kDebugMode) print('OnlineOrderService.publishStoreCatalog error: $e');
      return false;
    }
  }

  /// Fetches the store profile & menu for the customer-facing screen.
  Future<Map<String, dynamic>?> fetchStoreCatalog(String inputStoreKey) async {
    final storeId = await resolveStoreId(inputStoreKey);

    if (_isFlutterTest) {
      final profile = _localProfiles[storeId] ??
          OnlineStoreProfile(storeId: storeId, ownerEmail: '$storeId@store.com');
      final menu = _mockStoreMenus[storeId] ?? initialCelestialMenu;
      return {
        'profile': profile,
        'menu': menu,
      };
    }

    try {
      final profileUri = Uri.parse('$_rtdbUrl/online_stores/$storeId/profile.json');
      final menuUri = Uri.parse('$_rtdbUrl/online_stores/$storeId/menu.json');

      final responses = await Future.wait([
        http.get(profileUri).timeout(const Duration(seconds: 8)),
        http.get(menuUri).timeout(const Duration(seconds: 8)),
      ]);

      OnlineStoreProfile? profile;
      if (responses[0].statusCode == 200 && responses[0].body != 'null') {
        final map = jsonDecode(responses[0].body) as Map<String, dynamic>;
        profile = OnlineStoreProfile.fromJson(map);
      } else {
        profile = _localProfiles[storeId] ??
            OnlineStoreProfile(storeId: storeId, ownerEmail: '$storeId@store.com');
      }

      List<MenuItem> menu = [];
      if (responses[1].statusCode == 200 && responses[1].body != 'null') {
        final list = jsonDecode(responses[1].body) as List<dynamic>;
        menu = list.map((item) => MenuItem.fromJson(item as Map<String, dynamic>)).toList();
      }

      if (menu.isEmpty) {
        menu = _mockStoreMenus[storeId] ?? initialCelestialMenu;
      }

      return {
        'profile': profile,
        'menu': menu,
      };
    } catch (e) {
      if (kDebugMode) print('OnlineOrderService.fetchStoreCatalog error: $e');
      final fallbackProfile = _localProfiles[storeId] ??
          OnlineStoreProfile(storeId: storeId, ownerEmail: '$storeId@store.com');
      return {
        'profile': fallbackProfile,
        'menu': _mockStoreMenus[storeId] ?? initialCelestialMenu,
      };
    }
  }

  /// Places a customer's online order into the store's real-time incoming order queue.
  Future<bool> submitCustomerOrder({
    required String storeId,
    required Order order,
  }) async {
    final actualStoreId = await resolveStoreId(storeId);

    if (_isFlutterTest) {
      _mockStoreOrders.putIfAbsent(actualStoreId, () => []).insert(0, order);
      return true;
    }

    try {
      final uri = Uri.parse('$_rtdbUrl/online_stores/$actualStoreId/incoming_orders/${order.id}.json');
      final body = jsonEncode(order.toJson());
      final res = await http.put(uri, body: body).timeout(const Duration(seconds: 10));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      if (kDebugMode) print('OnlineOrderService.submitCustomerOrder error: $e');
      // Save in mock list as fallback
      _mockStoreOrders.putIfAbsent(actualStoreId, () => []).insert(0, order);
      return false;
    }
  }

  /// Polls the store's incoming online orders from Firebase for the POS terminal.
  Future<List<Order>> fetchIncomingOrders(String inputStoreKey) async {
    final storeId = await resolveStoreId(inputStoreKey);

    if (_isFlutterTest) {
      return _mockStoreOrders[storeId] ?? [];
    }

    try {
      final uri = Uri.parse('$_rtdbUrl/online_stores/$storeId/incoming_orders.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body != 'null') {
        final dynamic raw = jsonDecode(res.body);
        final List<Order> orders = [];

        if (raw is Map<String, dynamic>) {
          for (final entry in raw.entries) {
            if (entry.value is Map<String, dynamic>) {
              try {
                orders.add(Order.fromJson(entry.value as Map<String, dynamic>));
              } catch (_) {}
            }
          }
        } else if (raw is List<dynamic>) {
          for (final item in raw) {
            if (item is Map<String, dynamic>) {
              try {
                orders.add(Order.fromJson(item));
              } catch (_) {}
            }
          }
        }

        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return orders;
      }
    } catch (e) {
      if (kDebugMode) print('OnlineOrderService.fetchIncomingOrders error: $e');
    }

    return _mockStoreOrders[storeId] ?? [];
  }

  /// Updates the status of an online order (e.g. from Pending -> Kitchen Preparing -> Ready).
  Future<bool> updateOrderStatus({
    required String storeId,
    required String orderId,
    required OrderStatus newStatus,
    String? cashierName,
  }) async {
    final actualStoreId = await resolveStoreId(storeId);

    if (_mockStoreOrders.containsKey(actualStoreId)) {
      final idx = _mockStoreOrders[actualStoreId]!.indexWhere((o) => o.id == orderId);
      if (idx >= 0) {
        _mockStoreOrders[actualStoreId]![idx].status = newStatus;
        if (cashierName != null && cashierName.isNotEmpty) {
          _mockStoreOrders[actualStoreId]![idx].cashierName = cashierName;
        }
      }
    }

    if (_isFlutterTest) return true;

    try {
      final uri = Uri.parse('$_rtdbUrl/online_stores/$actualStoreId/incoming_orders/$orderId/status.json');
      await http.put(uri, body: jsonEncode(newStatus.name)).timeout(const Duration(seconds: 6));
      if (cashierName != null && cashierName.isNotEmpty) {
        final cashierUri = Uri.parse('$_rtdbUrl/online_stores/$actualStoreId/incoming_orders/$orderId/cashierName.json');
        await http.put(cashierUri, body: jsonEncode(cashierName)).timeout(const Duration(seconds: 6));
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('OnlineOrderService.updateOrderStatus error: $e');
      return false;
    }
  }

  /// Loads local store profile from SharedPreferences.
  Future<OnlineStoreProfile> loadLocalProfile(
    String storeId, {
    String? ownerEmail,
    String? defaultStoreName,
    String? defaultStoreAddress,
  }) async {
    if (_localProfiles.containsKey(storeId)) {
      return _localProfiles[storeId]!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'online_store_profile_$storeId';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final profile = OnlineStoreProfile.fromJson(map);
        _localProfiles[storeId] = profile;
        if (profile.customSlug != null && profile.customSlug!.isNotEmpty) {
          _slugToStoreIdCache[slugify(profile.customSlug!)] = profile.storeId;
          _slugToStoreIdCache[profile.customSlug!] = profile.storeId;
        }
        return profile;
      }
    } catch (e) {
      if (kDebugMode) print('loadLocalProfile error: $e');
    }

    final newProfile = OnlineStoreProfile(
      storeId: storeId,
      ownerEmail: ownerEmail ?? '',
      storeName: defaultStoreName ?? 'Celestial Cafe',
      storeAddress: defaultStoreAddress ?? '',
    );
    _localProfiles[storeId] = newProfile;
    return newProfile;
  }

  /// Saves local store profile to SharedPreferences.
  Future<void> saveLocalProfile(OnlineStoreProfile profile) async {
    _localProfiles[profile.storeId] = profile;
    if (profile.customSlug != null && profile.customSlug!.isNotEmpty) {
      _slugToStoreIdCache[slugify(profile.customSlug!)] = profile.storeId;
      _slugToStoreIdCache[profile.customSlug!] = profile.storeId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'online_store_profile_${profile.storeId}';
      await prefs.setString(key, jsonEncode(profile.toJson()));
    } catch (e) {
      if (kDebugMode) print('saveLocalProfile error: $e');
    }
  }
}
