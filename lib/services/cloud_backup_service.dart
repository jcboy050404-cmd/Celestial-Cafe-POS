import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../firebase_options.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
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
  static const String _pendingSalesQueuePrefix = 'pending_sales_sync_';

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

  static bool get _isFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  bool? isOnlineOverride;

  /// Checks if internet connectivity is available
  Future<bool> _isOnline() async {
    if (isOnlineOverride != null) return isOnlineOverride!;
    if (_isFlutterTest) return false;
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

  // ─────────────────────────────────────────────────────────────────────────
  // ── Monthly Sales Transactions Cloud Sync ────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────

  String _pendingSalesQueueKey(String email) =>
      '$_pendingSalesQueuePrefix${_sanitizeEmailKey(email)}';

  /// Retrieves list of orders waiting in the offline sync queue.
  Future<List<Order>> getPendingOrders(String userEmail) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingSalesQueueKey(cleanEmail);
      final rawList = prefs.getStringList(key) ?? [];
      final orders = <Order>[];
      for (final raw in rawList) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map<String, dynamic>) {
            orders.add(Order.fromJson(decoded));
          }
        } catch (e) {
          debugPrint('CloudBackup: Error parsing queued order: $e');
        }
      }
      return orders;
    } catch (e) {
      debugPrint('CloudBackup: Error reading pending queue: $e');
      return [];
    }
  }

  /// Gets the count of pending sales awaiting sync
  Future<int> getPendingSalesCount(String userEmail) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingSalesQueueKey(cleanEmail);
      return (prefs.getStringList(key) ?? []).length;
    } catch (_) {
      return 0;
    }
  }

  /// Enqueues an order to be synced to the cloud when offline or upload failed
  Future<void> enqueuePendingOrder({
    required String userEmail,
    required Order order,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingSalesQueueKey(cleanEmail);
      final rawList = prefs.getStringList(key) ?? [];
      final alreadyQueued = rawList.any((str) {
        try {
          final decoded = json.decode(str);
          return decoded['id'] == order.id;
        } catch (_) {
          return false;
        }
      });
      if (!alreadyQueued) {
        rawList.add(json.encode(order.toJson()));
        await prefs.setStringList(key, rawList);
        debugPrint(
          'CloudBackup: Enqueued order ${order.orderNumber} (${order.id}) for later cloud sync. Total queued: ${rawList.length}',
        );
      }
    } catch (e) {
      debugPrint('CloudBackup: Error enqueueing pending order: $e');
    }
  }

  /// Removes an order from the pending queue after successful sync
  Future<void> dequeuePendingOrder({
    required String userEmail,
    required String orderId,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _pendingSalesQueueKey(cleanEmail);
      final rawList = prefs.getStringList(key) ?? [];
      final originalLength = rawList.length;
      rawList.removeWhere((str) {
        try {
          final decoded = json.decode(str);
          return decoded['id'] == orderId;
        } catch (_) {
          return false;
        }
      });
      if (rawList.length != originalLength) {
        await prefs.setStringList(key, rawList);
      }
    } catch (e) {
      debugPrint('CloudBackup: Error dequeuing pending order: $e');
    }
  }

  /// Synchronizes all queued pending sales to Firebase.
  /// Returns the number of successfully synced orders.
  Future<int> syncPendingSalesQueue({
    required String userEmail,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 0;

    final queued = await getPendingOrders(cleanEmail);
    if (queued.isEmpty) return 0;

    final online = await _isOnline();
    if (!online) {
      debugPrint('CloudBackup: Device is offline. Deferring sync of ${queued.length} orders.');
      return 0;
    }

    int syncedCount = 0;
    for (final order in queued) {
      final ok = await recordMonthlySaleTransaction(
        userEmail: cleanEmail,
        order: order,
      );
      if (ok) {
        syncedCount++;
        await dequeuePendingOrder(userEmail: cleanEmail, orderId: order.id);
      } else {
        // Stop early if connection failed during the batch
        break;
      }
    }

    debugPrint('CloudBackup: Successfully synced $syncedCount offline orders to cloud.');
    return syncedCount;
  }

  /// Records a completed sales transaction in Firebase Realtime Database
  /// under: /sales_history/<emailKey>/<YYYY-MM>/<orderId>.json
  Future<bool> recordMonthlySaleTransaction({
    required String userEmail,
    required Order order,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    try {
      final emailKey = _sanitizeEmailKey(cleanEmail);
      final yearMonth =
          '${order.createdAt.year.toString().padLeft(4, '0')}-${order.createdAt.month.toString().padLeft(2, '0')}';

      final uri = Uri.parse('$_rtdbUrl/sales_history/$emailKey/$yearMonth/${order.id}.json');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(order.toJson()),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        debugPrint('CloudBackup: Recorded sale ${order.orderNumber} under $yearMonth for $cleanEmail');
        await dequeuePendingOrder(userEmail: cleanEmail, orderId: order.id);
        return true;
      } else {
        debugPrint('CloudBackup: Failed to record sale ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('CloudBackup: Sale record error: $e');
    }
    return false;
  }

  /// Fetches monthly sales history from Firebase Realtime Database
  /// for a specific month (e.g. '2026-09')
  Future<List<Order>> fetchMonthlySalesHistory({
    required String userEmail,
    required String yearMonth,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return [];

    try {
      final emailKey = _sanitizeEmailKey(cleanEmail);
      final uri = Uri.parse('$_rtdbUrl/sales_history/$emailKey/$yearMonth.json');

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final decoded = json.decode(res.body);
        if (decoded is Map<String, dynamic>) {
          final orders = <Order>[];
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              try {
                orders.add(Order.fromJson(value));
              } catch (e) {
                debugPrint('CloudBackup: Error parsing order $key: $e');
              }
            }
          });
          orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        }
      }
    } catch (e) {
      debugPrint('CloudBackup: Failed to fetch monthly sales: $e');
    }
    return [];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ── Menu Catalog & Categories Cloud Sync ─────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────

  /// Synchronizes full menu items and custom categories to Firebase Realtime Database
  /// under: /menu_catalog/<emailKey>.json
  Future<bool> syncMenuToCloud({
    required String userEmail,
    required List<MenuItem> menuItems,
    required List<CustomCategory> customCategories,
  }) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return false;

    try {
      final emailKey = _sanitizeEmailKey(cleanEmail);
      final uri = Uri.parse('$_rtdbUrl/menu_catalog/$emailKey.json');

      final payload = {
        'updatedAt': DateTime.now().toIso8601String(),
        'menuItems': menuItems.map((m) => m.toJson()).toList(),
        'customCategories': customCategories.map((c) => c.toJson()).toList(),
      };

      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        debugPrint('CloudBackup: Successfully synced menu catalog to Firebase for $cleanEmail');
        return true;
      } else {
        debugPrint('CloudBackup: Failed to sync menu: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('CloudBackup: Menu sync error: $e');
    }
    return false;
  }

  /// Fetches cloud menu catalog and categories for the given user email.
  Future<Map<String, dynamic>?> fetchMenuFromCloud(String userEmail) async {
    final cleanEmail = userEmail.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      final emailKey = _sanitizeEmailKey(cleanEmail);
      final uri = Uri.parse('$_rtdbUrl/menu_catalog/$emailKey.json');

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final data = json.decode(res.body);
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('CloudBackup: Fetch menu error: $e');
    }
    return null;
  }
}

