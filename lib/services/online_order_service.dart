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

  /// Constructs the public customer web ordering URL for a given store.
  static String getOrderingUrl({
    required String storeId,
    String? tableNumber,
    String baseUrl = 'https://celestialcafe.web.app',
  }) {
    final buffer = StringBuffer('$baseUrl/#/order?store=$storeId');
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

    if (_isFlutterTest) {
      _mockStoreMenus[profile.storeId] = List.from(menuItems);
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
  Future<Map<String, dynamic>?> fetchStoreCatalog(String storeId) async {
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
    if (_isFlutterTest) {
      _mockStoreOrders.putIfAbsent(storeId, () => []).insert(0, order);
      return true;
    }

    try {
      final uri = Uri.parse('$_rtdbUrl/online_stores/$storeId/incoming_orders/${order.id}.json');
      final body = jsonEncode(order.toJson());
      final res = await http.put(uri, body: body).timeout(const Duration(seconds: 10));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      if (kDebugMode) print('OnlineOrderService.submitCustomerOrder error: $e');
      // Save in mock list as fallback
      _mockStoreOrders.putIfAbsent(storeId, () => []).insert(0, order);
      return false;
    }
  }

  /// Polls the store's incoming online orders from Firebase for the POS terminal.
  Future<List<Order>> fetchIncomingOrders(String storeId) async {
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
    if (_mockStoreOrders.containsKey(storeId)) {
      final idx = _mockStoreOrders[storeId]!.indexWhere((o) => o.id == orderId);
      if (idx >= 0) {
        _mockStoreOrders[storeId]![idx].status = newStatus;
        if (cashierName != null && cashierName.isNotEmpty) {
          _mockStoreOrders[storeId]![idx].cashierName = cashierName;
        }
      }
    }

    if (_isFlutterTest) return true;

    try {
      final uri = Uri.parse('$_rtdbUrl/online_stores/$storeId/incoming_orders/$orderId/status.json');
      await http.put(uri, body: jsonEncode(newStatus.name)).timeout(const Duration(seconds: 6));
      if (cashierName != null && cashierName.isNotEmpty) {
        final cashierUri = Uri.parse('$_rtdbUrl/online_stores/$storeId/incoming_orders/$orderId/cashierName.json');
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'online_store_profile_${profile.storeId}';
      await prefs.setString(key, jsonEncode(profile.toJson()));
    } catch (e) {
      if (kDebugMode) print('saveLocalProfile error: $e');
    }
  }
}
