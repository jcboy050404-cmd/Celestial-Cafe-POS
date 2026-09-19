import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../services/online_order_service.dart';
import '../theme/celestial_theme.dart';
import '../widgets/client_menu_item_card.dart';
import '../widgets/customization_dialog.dart';
import '../widgets/top_notification.dart';

/// Public customer-facing web & mobile screen allowing customers anywhere to browse a store's menu and order online.
class CustomerOnlineOrderScreen extends StatefulWidget {
  final String storeId;
  final String? initialTable;
  final bool previewMode;

  const CustomerOnlineOrderScreen({
    super.key,
    required this.storeId,
    this.initialTable,
    this.previewMode = false,
  });

  @override
  State<CustomerOnlineOrderScreen> createState() => _CustomerOnlineOrderScreenState();
}

class _CustomerOnlineOrderScreenState extends State<CustomerOnlineOrderScreen> {
  bool _isLoading = true;
  String? _storeLoadError;
  OnlineStoreProfile? _profile;
  List<MenuItem> _menuItems = [];
  String _selectedCategory = 'all';
  String _searchQuery = '';

  // Cart
  final List<OrderItem> _cart = [];

  // Active Submitted Order (for Live Tracking & Re-entry)
  Order? _submittedOrder;
  final List<Order> _recentOrders = [];
  bool _isViewingTracker = false;
  Timer? _statusTrackerTimer;
  Timer? _profileSyncTimer;
  final ScrollController _scrollController = ScrollController();
  String? _resolvedStoreId;
  bool _hasShownClosedModal = false;
  bool _isClosedModalOpen = false;
  final Set<String> _notifiedStatusKeys = {};
  bool _isReadyModalOpen = false;

  void _showClosedStoreModal() {
    if (!mounted || _isClosedModalOpen) return;
    final isOpen = _profile?.isOpen ?? true;
    if (isOpen) return;

    _isClosedModalOpen = true;

    final hasNotice = _profile?.customNotice?.trim().isNotEmpty == true;
    final cleanNotice = _profile?.customNotice?.trim() ?? '';
    final message = hasNotice
        ? cleanNotice
        : 'The café is currently closed and not accepting online orders right now. You can still browse our menu items!';
    PosProvider? pos;
    try {
      pos = Provider.of<PosProvider>(context, listen: false);
    } catch (_) {}
    final storeName = (pos != null && pos.storeName.isNotEmpty && pos.storeName != 'CELESTIAL CAFE')
        ? pos.storeName
        : (_profile?.storeName ?? 'Celestial Cafe');

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (ctx) => Dialog(
        key: const ValueKey('closed_store_modal'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: CelestialTheme.bgSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar: Close Button
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: CelestialTheme.textMuted,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  tooltip: 'Close and Browse Menu',
                ),
              ),

              // Status Icon Header
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CelestialTheme.roseAlert.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CelestialTheme.roseAlert.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.lock_clock_rounded,
                    size: 26,
                    color: CelestialTheme.roseAlert,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Closed Badge & Title
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: CelestialTheme.roseAlert.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: CelestialTheme.roseAlert.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'CLOSED',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: CelestialTheme.roseAlert,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Text(
                    'ONLINE ORDERING IS PAUSED',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: CelestialTheme.creamLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Store Name
              Text(
                storeName,
                style: GoogleFonts.cinzel(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: CelestialTheme.textLight,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Notice Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      message,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: CelestialTheme.creamLight,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Checkout is temporarily paused until the store reopens. You can still browse our menu, prices, and drinks while you wait!',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: CelestialTheme.textMuted,
                        height: 1.35,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Primary Action: Browse Menu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.primaryBtnText,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Browse Menu',
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isClosedModalOpen = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadStoreData();
    _startProfileSyncTimer();
  }

  @override
  void dispose() {
    _statusTrackerTimer?.cancel();
    _profileSyncTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startProfileSyncTimer() {
    _profileSyncTimer?.cancel();
    _profileSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final targetStore = _resolvedStoreId ?? widget.storeId;
      final data = await OnlineOrderService().fetchStoreCatalog(targetStore);
      if (mounted && data != null) {
        final newProfile = data['profile'] as OnlineStoreProfile?;
        if (newProfile != null &&
            (newProfile.isOpen != _profile?.isOpen ||
             newProfile.customNotice != _profile?.customNotice ||
             newProfile.storeName != _profile?.storeName ||
             newProfile.storeTagline != _profile?.storeTagline ||
             newProfile.storeLogoBase64 != _profile?.storeLogoBase64)) {
          final becameClosed = (_profile?.isOpen ?? true) && !newProfile.isOpen;
          setState(() {
            _profile = newProfile;
          });
          if (becameClosed) {
            _showClosedStoreModal();
          }
        }
      }
    });
  }

  Future<void> _loadStoreData() async {
    setState(() {
      _isLoading = true;
      _storeLoadError = null;
    });

    try {
      final resolved = await OnlineOrderService().resolveStoreId(widget.storeId);
      _resolvedStoreId = resolved;
      final data = await OnlineOrderService().fetchStoreCatalog(resolved);
      if (!mounted) return;

      if (data != null) {
        _profile = data['profile'] as OnlineStoreProfile?;
        _menuItems = (data['menu'] as List<MenuItem>?) ?? [];
      } else {
        _storeLoadError = 'Unable to reach the café catalog. The store may be offline or updating its menu.';
      }

      // Direct PosProvider fallback & heal if running on device / within app
      if (_profile != null) {
        try {
          final pos = Provider.of<PosProvider>(context, listen: false);
          bool shouldHealCloud = false;
          if (pos.customLogoBase64 != null &&
              pos.customLogoBase64!.isNotEmpty &&
              _profile!.storeLogoBase64 != pos.customLogoBase64) {
            _profile!.storeLogoBase64 = pos.customLogoBase64;
            shouldHealCloud = true;
          }
          if (pos.storeTagline.isNotEmpty &&
              pos.storeTagline != _profile!.storeTagline) {
            _profile!.storeTagline = pos.storeTagline;
            shouldHealCloud = true;
          }
          if (pos.storeName.isNotEmpty &&
              pos.storeName != 'CELESTIAL CAFE' &&
              pos.storeName != _profile!.storeName) {
            _profile!.storeName = pos.storeName;
            shouldHealCloud = true;
          }
          if (shouldHealCloud) {
            unawaited(OnlineOrderService().updateStoreProfile(_profile!));
          }
        } catch (_) {}
      }

      // Auto restore recent order from local cache if within 24h
      await _loadRecentOrderLocally(resolved);

      // Auto popup modal if store is currently closed
      if (_profile != null && !_profile!.isOpen && !_hasShownClosedModal) {
        _hasShownClosedModal = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showClosedStoreModal();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _storeLoadError = 'Connection timeout. Please check your internet connection and try again.';
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _upsertRecentOrder(Order order) {
    final idx = _recentOrders.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      _recentOrders[idx] = order;
    } else {
      _recentOrders.insert(0, order);
    }
  }

  Future<void> _saveRecentOrdersLocally(String targetStore) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final validOrders = _recentOrders.where(
        (o) => DateTime.now().difference(o.createdAt).inHours < 24,
      ).take(15).toList();
      final jsonList = validOrders.map((o) => o.toJson()).toList();
      await prefs.setString('customer_recent_orders_$targetStore', jsonEncode(jsonList));
      if (validOrders.isNotEmpty) {
        await prefs.setString('customer_recent_order_$targetStore', jsonEncode(validOrders.first.toJson()));
      } else {
        await prefs.remove('customer_recent_order_$targetStore');
      }
    } catch (e) {
      debugPrint('Error saving recent orders locally: $e');
    }
  }

  Future<void> _dismissRecentOrder(String targetStore, String orderId) async {
    setState(() {
      _recentOrders.removeWhere((o) => o.id == orderId);
      if (_submittedOrder?.id == orderId) {
        final activeRemaining = _recentOrders.where(
          (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
        ).toList();
        _submittedOrder = activeRemaining.isNotEmpty ? activeRemaining.first : null;
      }
    });
    final hasActive = _recentOrders.any(
      (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
    );
    if (!hasActive) {
      _statusTrackerTimer?.cancel();
    }
    await _saveRecentOrdersLocally(targetStore);
  }

  Future<void> _recordNotifiedStatus(String targetStore, String key) async {
    try {
      _notifiedStatusKeys.add(key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('customer_notified_statuses_$targetStore', _notifiedStatusKeys.toList());
    } catch (e) {
      debugPrint('Error recording notified status: $e');
    }
  }

  Future<void> _loadRecentOrderLocally(String targetStore) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifiedList = prefs.getStringList('customer_notified_statuses_$targetStore') ?? [];
      _notifiedStatusKeys.addAll(notifiedList);

      _recentOrders.clear();
      final listJsonStr = prefs.getString('customer_recent_orders_$targetStore');
      if (listJsonStr != null && listJsonStr.isNotEmpty) {
        final list = jsonDecode(listJsonStr) as List<dynamic>;
        for (final item in list) {
          final order = Order.fromJson(item as Map<String, dynamic>);
          if (DateTime.now().difference(order.createdAt).inHours < 24) {
            _recentOrders.add(order);
          }
        }
      }

      // Fallback: check single-order key if list is empty
      if (_recentOrders.isEmpty) {
        final singleJsonStr = prefs.getString('customer_recent_order_$targetStore');
        if (singleJsonStr != null && singleJsonStr.isNotEmpty) {
          final map = jsonDecode(singleJsonStr) as Map<String, dynamic>;
          final order = Order.fromJson(map);
          if (DateTime.now().difference(order.createdAt).inHours < 24) {
            _recentOrders.add(order);
          }
        }
      }

      if (_recentOrders.isNotEmpty && mounted) {
        final activeOrders = _recentOrders.where(
          (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
        ).toList();
        if (activeOrders.isNotEmpty) {
          _startOrderTracking(activeOrders.first, switchToTracker: false);
        } else {
          // All cached orders are completed or cancelled: keep them in _recentOrders for history
          // but do not track or poll completed orders again.
          _submittedOrder = null;
          _statusTrackerTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint('Error loading recent orders: $e');
    }
  }

  void _startOrderTracking(Order order, {bool switchToTracker = true}) {
    _submittedOrder = order;
    _upsertRecentOrder(order);
    if (switchToTracker) {
      _isViewingTracker = true;
    }
    final targetStore = _resolvedStoreId ?? widget.storeId;
    _saveRecentOrdersLocally(targetStore);

    Future<void> pollOrders() async {
      if (!mounted || _recentOrders.isEmpty) return;
      try {
        final incomingOrders = await OnlineOrderService().fetchIncomingOrders(targetStore);
        if (!mounted || _recentOrders.isEmpty) return;

        bool hasChanges = false;
        for (int i = 0; i < _recentOrders.length; i++) {
          final current = _recentOrders[i];
          final updated = incomingOrders.firstWhere(
            (o) => o.id == current.id,
            orElse: () => current,
          );
          if (updated.status != current.status) {
            final previousStatus = current.status;
            _recentOrders[i] = updated;
            hasChanges = true;
            if (_submittedOrder?.id == current.id) {
              _submittedOrder = updated;
            }
            _checkAndShowOrderReadyModal(updated, previousStatus: previousStatus);
          } else if (updated.status == OrderStatus.ready ||
              updated.status == OrderStatus.outForDelivery ||
              updated.status == OrderStatus.completed) {
            _checkAndShowOrderReadyModal(updated);
          }
        }

        final hasActiveOrders = _recentOrders.any(
          (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
        );
        if (!hasActiveOrders) {
          _statusTrackerTimer?.cancel();
        }

        if (hasChanges && mounted) {
          setState(() {});
          _saveRecentOrdersLocally(targetStore);
        }
      } catch (e) {
        debugPrint('Error polling orders status: $e');
      }
    }

    // Run immediate check
    pollOrders();

    _statusTrackerTimer?.cancel();
    _statusTrackerTimer = Timer.periodic(const Duration(seconds: 6), (_) => pollOrders());
  }

  void _checkAndShowOrderReadyModal(Order order, {OrderStatus? previousStatus}) {
    if (!mounted) return;
    if (order.status != OrderStatus.ready &&
        order.status != OrderStatus.outForDelivery &&
        order.status != OrderStatus.completed) {
      return;
    }
    final notifyKey = '${order.id}_${order.status.name}';
    if (_notifiedStatusKeys.contains(notifyKey) || _isReadyModalOpen) {
      return;
    }

    final targetStore = _resolvedStoreId ?? widget.storeId;
    _recordNotifiedStatus(targetStore, notifyKey);

    // Audio & Haptic chime
    try {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}

    _showOrderReadyModal(order);
  }

  void _showOrderReadyModal(Order order) {
    if (!mounted || _isReadyModalOpen) return;
    _isReadyModalOpen = true;

    final isDelivery = order.orderType == OrderType.delivery;
    final isDineIn = order.orderType == OrderType.dineIn;
    final isOutForDelivery = order.status == OrderStatus.outForDelivery;
    final isCompleted = order.status == OrderStatus.completed;

    final Color accentColor = isOutForDelivery
        ? Colors.cyanAccent
        : CelestialTheme.emeraldReady;

    final IconData mainIcon = (isDelivery || isOutForDelivery)
        ? Icons.delivery_dining_rounded
        : (isDineIn ? Icons.restaurant_rounded : Icons.check_circle_rounded);

    final String badgeLabel = isDelivery
        ? (isOutForDelivery ? 'OUT FOR DELIVERY' : (isCompleted ? 'DELIVERED' : 'READY FOR DELIVERY'))
        : (isDineIn ? 'READY AT CASHIER' : 'READY FOR PICKUP');

    final String headline = isDelivery
        ? (isCompleted ? 'Order Completed • Arrived!' : 'Your Order is on the Way!')
        : (isDineIn && order.tableNumber != null && order.tableNumber!.isNotEmpty
            ? 'Table ${order.tableNumber}: Ready to Pickup on Cashier!'
            : 'Your Order is Ready to Pickup on Cashier!');

    final String subMessage = isDelivery
        ? (isCompleted
            ? 'Please wait the order arrive if your rider is arriving, or verify your items. Thank you!'
            : (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty
                ? 'Please wait the order arrive. Your delivery rider is heading to ${order.deliveryAddress}. Please keep your phone reachable!'
                : 'Please wait the order arrive. Your delivery rider is heading your way. Please keep your phone reachable!'))
        : (isDineIn
            ? (order.tableNumber != null && order.tableNumber!.isNotEmpty
                ? 'Your order is ready to pickup on cashier! Please proceed to the cashier counter for Table ${order.tableNumber}.'
                : 'Your order is ready to pickup on cashier! Please proceed to the cashier counter to claim your order.')
            : 'Your order is ready to pickup on cashier! Please proceed to the cashier counter and show Order #${order.orderNumber}.');

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (ctx) => Dialog(
        key: const ValueKey('order_ready_notification_modal'),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          width: 460,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: CelestialTheme.bgSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.40),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar with close button & category label
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_active_rounded, size: 13, color: accentColor),
                          const SizedBox(width: 5),
                          Text(
                            badgeLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: CelestialTheme.textMuted,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Close Notification',
                    ),
                  ],
                ),
              ),

              // Scrollable dialog body to prevent any overflow on small screens
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.14),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(mainIcon, size: 30, color: accentColor),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Order Number Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          order.orderNumber,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: CelestialTheme.goldLight,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Headline
                      Text(
                        headline,
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),

                      // Sub-message
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          subMessage,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: CelestialTheme.creamLight.withValues(alpha: 0.85),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Order Breakdown Box
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: CelestialTheme.bgCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CelestialTheme.borderWarm,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                              child: Row(
                                children: [
                                  Icon(Icons.receipt_rounded, size: 15, color: CelestialTheme.goldLight),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Order Breakdown',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.textLight,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.caramelAccent.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      order.orderType.label,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.goldLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(color: CelestialTheme.borderWarm, height: 1),

                            // Items List Preview
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  for (int i = 0; i < order.items.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        color: CelestialTheme.borderSubtle.withValues(alpha: 0.5),
                                        height: 12,
                                      ),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '${order.items[i].quantity}×',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: CelestialTheme.goldLight,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                order.items[i].menuItem.name,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: CelestialTheme.textLight,
                                                ),
                                              ),
                                              if (order.items[i].customizations.isNotEmpty)
                                                Text(
                                                  order.items[i].customizations.map((c) => c.optionName).join(', '),
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: CelestialTheme.textMuted,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₱${_formatPrice(order.items[i].totalPrice)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.bold,
                                            color: CelestialTheme.goldLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Divider(color: CelestialTheme.borderWarm, height: 1),

                            // Total and Customer details row
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (order.customerName.isNotEmpty)
                                          Text(
                                            'Customer: ${order.customerName}',
                                            style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        Text(
                                          'Payment: ${order.paymentMethod.name.toUpperCase()}',
                                          style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Row(
                                    children: [
                                      Text(
                                        'Total: ',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.textLight,
                                        ),
                                      ),
                                      Text(
                                        '₱${_formatPrice(order.totalAmount)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: CelestialTheme.goldLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Buttons
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (!_isViewingTracker) ...[
                                Expanded(
                                  child: OutlinedButton(
                                    key: const ValueKey('ready_modal_view_tracker_btn'),
                                    onPressed: () {
                                      Navigator.of(ctx).pop();
                                      setState(() {
                                        _isViewingTracker = true;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.6)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.timeline_rounded, size: 16, color: CelestialTheme.goldLight),
                                        const SizedBox(width: 6),
                                        Text(
                                          'View Tracker',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: CelestialTheme.goldLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Expanded(
                                child: ElevatedButton(
                                  key: const ValueKey('ready_modal_got_it_btn'),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentColor,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    'Got it, Thanks!',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isOutForDelivery ? Colors.black : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isReadyModalOpen = false;
    });
  }

  ({String title, String badge, Color color, IconData icon}) _getOrderStatusMeta(Order order) {
    switch (order.status) {
      case OrderStatus.pending:
        return (
          title: 'Order Sent • Waiting Confirmation',
          badge: 'Order Sent',
          color: CelestialTheme.goldPrimary,
          icon: Icons.send_rounded,
        );
      case OrderStatus.confirmed:
        return (
          title: 'Order Confirmed by Cashier',
          badge: 'Confirmed',
          color: CelestialTheme.goldPrimary,
          icon: Icons.thumb_up_alt_rounded,
        );
      case OrderStatus.preparing:
        return (
          title: 'Kitchen is Preparing',
          badge: 'Preparing',
          color: CelestialTheme.goldPrimary,
          icon: Icons.local_fire_department_rounded,
        );
      case OrderStatus.ready:
        return (
          title: order.orderType == OrderType.delivery ? 'Ready for Delivery' : 'Ready for Pickup',
          badge: 'Ready',
          color: CelestialTheme.emeraldReady,
          icon: Icons.check_circle_rounded,
        );
      case OrderStatus.outForDelivery:
        return (
          title: 'Out for Delivery',
          badge: 'On the way',
          color: Colors.cyanAccent,
          icon: Icons.delivery_dining_rounded,
        );
      case OrderStatus.completed:
        return (
          title: 'Order Completed',
          badge: 'Completed',
          color: CelestialTheme.emeraldReady,
          icon: Icons.verified_rounded,
        );
      case OrderStatus.cancelled:
        return (
          title: 'Order Cancelled',
          badge: 'Cancelled',
          color: CelestialTheme.roseAlert,
          icon: Icons.cancel_outlined,
        );
    }
  }

  List<({String key, String label, String icon})> get _categoryTabs {
    final tabs = <({String key, String label, String icon})>[
      (key: 'all', label: 'All Items', icon: '✨'),
    ];
    final seen = <String>{};
    for (var item in _menuItems) {
      final key = item.customCategory ?? item.category.name;
      if (!seen.contains(key)) {
        seen.add(key);
        final label = item.customCategory ?? item.category.label;
        final icon = item.customCategory != null ? '🏷️' : item.category.icon;
        tabs.add((key: key, label: label, icon: icon));
      }
    }
    return tabs;
  }

  List<MenuItem> get _filteredItems {
    return _menuItems.where((item) {
      final cat = item.customCategory ?? item.category.name;
      final matchesCat = _selectedCategory == 'all' || cat == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();
  }

  double get _cartTotal => _cart.fold(0.0, (sum, i) => sum + i.totalPrice);
  int get _cartItemCount => _cart.fold(0, (sum, i) => sum + i.quantity);

  String _formatPrice(double amount) {
    if (amount % 1 == 0) {
      return amount.toInt().toString();
    }
    return amount.toStringAsFixed(2);
  }

  MenuItem? get _bestSellerItem {
    if (_menuItems.isEmpty) return null;
    final inStockItems = _menuItems.where((m) => m.inStock).toList();
    if (inStockItems.isEmpty) return null;

    final candidatePool = _selectedCategory == 'all'
        ? inStockItems
        : inStockItems.where((m) => (m.customCategory ?? m.category.name) == _selectedCategory).toList();
    if (candidatePool.isEmpty) return null;

    // Prioritize items tagged with best seller or signature classics
    final tagged = candidatePool.where((m) =>
        m.tags.any((t) =>
            t.toLowerCase().contains('best') ||
            t.toLowerCase().contains('seller') ||
            t.toLowerCase().contains('popular')) ||
        m.name.toLowerCase().contains('spanish latte') ||
        m.name.toLowerCase().contains('caramel macchiato') ||
        m.name.toLowerCase().contains('signature') ||
        m.name.toLowerCase().contains('americano') ||
        m.name.toLowerCase().contains('dirty matcha'));
    if (tagged.isNotEmpty) return tagged.first;

    candidatePool.sort((a, b) => b.rating.compareTo(a.rating));
    return candidatePool.first;
  }

  Widget _buildBestSellerBanner(MenuItem item, bool isOpen) {
    final isAvailable = item.inStock && isOpen;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 760;
        final badgeText = isDesktop ? 'CELESTIAL SIGNATURE CRAFT' : 'SIGNATURE CRAFT';
        final titleText = item.name;
        final subtitleText = item.description.isNotEmpty
            ? item.description
            : 'House specialty handcrafted celestial latte blend with silky sweet foam';

        return Container(
          margin: EdgeInsets.fromLTRB(isDesktop ? 16 : 12, 6, isDesktop ? 16 : 12, 6),
          decoration: CelestialTheme.tactileHero(),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isAvailable
                  ? () => _openCustomizationSheet(item)
                  : () {
                      if (!isOpen) {
                        _showClosedStoreModal();
                      } else {
                        TopNotification.show(
                          context,
                          message: '${item.name} is currently sold out.',
                          type: TopNotificationType.info,
                        );
                      }
                    },
              child: Stack(
                children: [
                  // Background realistic coffee photography with soft smooth vignette
                  Positioned.fill(
                    child: Row(
                      children: [
                        const Spacer(flex: 2),
                        Expanded(
                          flex: 3,
                          child: ShaderMask(
                            shaderCallback: (rect) {
                              return const LinearGradient(
                                colors: [Colors.transparent, Colors.black54, Colors.black],
                                stops: [0.0, 0.4, 1.0],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ).createShader(rect);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              'assets/images/hero_coffee_splash.jpg',
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(color: CelestialTheme.bgCardHover),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Layer
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 20 : 14,
                      vertical: isDesktop ? 14 : 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Badge: ✨ CELESTIAL SIGNATURE CRAFT
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: CelestialTheme.caramelAccent.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: CelestialTheme.caramelAccent.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('✨', style: TextStyle(fontSize: 11)),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        badgeText,
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.goldLight,
                                          letterSpacing: 0.6,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                titleText,
                                style: GoogleFonts.outfit(
                                  fontSize: isDesktop ? 17 : 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.creamLight,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitleText,
                                style: GoogleFonts.outfit(
                                  fontSize: isDesktop ? 11.5 : 10,
                                  color: CelestialTheme.creamSoft,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Quick explore / order button [ ✨ Order ]
                        ElevatedButton.icon(
                          onPressed: isAvailable
                              ? () => _openCustomizationSheet(item)
                              : () {
                                  if (!isOpen) {
                                    _showClosedStoreModal();
                                  } else {
                                    TopNotification.show(
                                      context,
                                      message: '${item.name} is currently sold out.',
                                      type: TopNotificationType.info,
                                    );
                                  }
                                },
                          icon: Icon(
                            isAvailable
                                ? Icons.auto_awesome_rounded
                                : (!isOpen ? Icons.lock_outline_rounded : Icons.block_rounded),
                            size: 14,
                          ),
                          label: Text(
                            isAvailable ? 'Order' : (!isOpen ? 'Closed' : 'Sold Out'),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isAvailable
                                ? CelestialTheme.caramelAccent
                                : CelestialTheme.bgSurface.withValues(alpha: 0.7),
                            foregroundColor: isAvailable
                                ? CelestialTheme.primaryBtnText
                                : CelestialTheme.textMuted,
                            elevation: isAvailable ? 2 : 0,
                            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _addToCart(MenuItem item, {List<SelectedCustomization> customizations = const [], String? notes}) {
    final customHash = customizations.map((c) => '${c.groupTitle}:${c.optionName}').join('|');
    final cartItemId = '${item.id}_${customHash}_${notes ?? ''}';

    final idx = _cart.indexWhere((i) => i.id == cartItemId);
    if (idx >= 0) {
      _cart[idx].quantity += 1;
    } else {
      _cart.add(OrderItem(
        id: cartItemId,
        menuItem: item,
        quantity: 1,
        customizations: customizations,
        notes: notes,
      ));
    }
    setState(() {});
  }

  void _openCustomizationSheet(MenuItem item) {
    final isOpen = _profile?.isOpen ?? true;
    if (!isOpen) {
      _showClosedStoreModal();
      return;
    }

    if (item.customizationGroups.isEmpty) {
      _addToCart(item);
      TopNotification.showSuccess(
        context,
        'Added ${item.name} to cart',
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => CustomizationDialog(
        item: item,
        isCustomerView: true,
        onAddToCart: (quantity, customizations, notes) {
          for (int q = 0; q < quantity; q++) {
            _addToCart(
              item,
              customizations: customizations,
              notes: notes,
            );
          }
          TopNotification.showSuccess(
            context,
            'Added $quantity× ${item.name} to cart',
          );
        },
      ),
    );
  }

  void _openCheckoutSheet() {
    final isOpen = _profile?.isOpen ?? true;
    if (!isOpen) {
      final msg = _profile?.customNotice?.trim().isNotEmpty == true
          ? _profile!.customNotice!.trim()
          : 'The café is currently closed. Online orders cannot be placed right now.';
      TopNotification.show(context, message: msg, type: TopNotificationType.warning);
      return;
    }

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final tableCtrl = TextEditingController(text: widget.initialTable ?? 'Table 01');
    final addressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    OrderType selectedType = _profile?.allowTakeaway == true
        ? OrderType.takeaway
        : (_profile?.allowDineIn == true ? OrderType.dineIn : OrderType.delivery);

    PaymentMethod selectedPayment = PaymentMethod.cash;
    bool isSubmitting = false;
    String? nameError;
    String? phoneError;
    String? addressError;
    String? tableError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final isDelivery = selectedType == OrderType.delivery;
          final isDineIn = selectedType == OrderType.dineIn;

          return Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Container(
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: CelestialTheme.borderWarm,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sheet Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: CelestialTheme.caramelAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.shopping_bag_outlined,
                            color: CelestialTheme.goldLight,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Complete Your Order',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              Text(
                                '$_cartItemCount item${_cartItemCount != 1 ? 's' : ''} • Total: ₱${_formatPrice(_cartTotal)}',
                                style: GoogleFonts.outfit(
                                  color: CelestialTheme.goldLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: CelestialTheme.textMuted, size: 22),
                          onPressed: () => Navigator.pop(sheetCtx),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Order Summary Items Card (Interactive Edit & Modify)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CelestialTheme.bgCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CelestialTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 14, color: CelestialTheme.goldLight),
                              const SizedBox(width: 6),
                              Text(
                                'ORDER SUMMARY',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.goldLight,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_cart.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.remove_shopping_cart_outlined,
                                        size: 28, color: CelestialTheme.textMuted.withValues(alpha: 0.6)),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Your cart is empty',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: CelestialTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: () => Navigator.pop(sheetCtx),
                                      icon: const Icon(Icons.add_rounded, size: 15),
                                      label: const Text('Add Items from Menu'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: CelestialTheme.goldLight,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 320),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _cart.length,
                                itemBuilder: (_, idx) {
                                  final it = _cart[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: CelestialTheme.bgCardHover,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: CelestialTheme.borderSubtle.withValues(alpha: 0.7),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        // Left side: Name, Customization Chips, Price
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                it.menuItem.name,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: CelestialTheme.textLight,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (it.customizations.isNotEmpty) ...[
                                                const SizedBox(height: 5),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: it.customizations.map((c) {
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 2.5),
                                                      decoration: BoxDecoration(
                                                        color: CelestialTheme.goldLight
                                                            .withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(7),
                                                        border: Border.all(
                                                          color: CelestialTheme.goldLight
                                                              .withValues(alpha: 0.35),
                                                          width: 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        c.optionName,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: CelestialTheme.goldLight,
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                              const SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  Text(
                                                    '₱${_formatPrice(it.totalPrice)}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: CelestialTheme.goldLight,
                                                    ),
                                                  ),
                                                  if (it.quantity > 1) ...[
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      '(₱${_formatPrice(it.unitPrice)} ea)',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: CelestialTheme.textMuted,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Right side controls: Stepper Pill [- 1 +] & Red Delete Button [X]
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Stepper Pill [- 1 +]
                                            Container(
                                              height: 34,
                                              decoration: BoxDecoration(
                                                color: CelestialTheme.bgSurface,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: CelestialTheme.borderWarm.withValues(alpha: 0.5),
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // Decrement
                                                  InkWell(
                                                    key: ValueKey('cart_qty_minus_$idx'),
                                                    onTap: () {
                                                      setSheetState(() {
                                                        setState(() {
                                                          if (it.quantity > 1) {
                                                            it.quantity -= 1;
                                                          } else {
                                                            _cart.removeAt(idx);
                                                          }
                                                        });
                                                      });
                                                    },
                                                    borderRadius: const BorderRadius.horizontal(
                                                        left: Radius.circular(7)),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 6),
                                                      child: Icon(
                                                        Icons.remove_rounded,
                                                        size: 14,
                                                        color: CelestialTheme.goldLight,
                                                      ),
                                                    ),
                                                  ),
                                                  // Quantity Number
                                                  Container(
                                                    constraints: const BoxConstraints(minWidth: 22),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '${it.quantity}',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: CelestialTheme.goldLight,
                                                      ),
                                                    ),
                                                  ),
                                                  // Increment
                                                  InkWell(
                                                    key: ValueKey('cart_qty_plus_$idx'),
                                                    onTap: () {
                                                      setSheetState(() {
                                                        setState(() {
                                                          it.quantity += 1;
                                                        });
                                                      });
                                                    },
                                                    borderRadius: const BorderRadius.horizontal(
                                                        right: Radius.circular(7)),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 6),
                                                      child: Icon(
                                                        Icons.add_rounded,
                                                        size: 14,
                                                        color: CelestialTheme.goldLight,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Red Delete Button [X]
                                            InkWell(
                                              key: ValueKey('cart_delete_btn_$idx'),
                                              onTap: () {
                                                setSheetState(() {
                                                  setState(() {
                                                    _cart.removeAt(idx);
                                                  });
                                                });
                                              },
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                width: 34,
                                                height: 34,
                                                decoration: BoxDecoration(
                                                  color: CelestialTheme.roseAlert.withValues(alpha: 0.16),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color:
                                                        CelestialTheme.roseAlert.withValues(alpha: 0.45),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                alignment: Alignment.center,
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                  color: CelestialTheme.roseAlert,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),

                          // Action: Add More Items
                          if (_cart.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Divider(
                              color: CelestialTheme.borderSubtle.withValues(alpha: 0.4),
                              height: 1,
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: InkWell(
                                key: const ValueKey('cart_add_more_btn'),
                                onTap: () => Navigator.pop(sheetCtx),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_rounded,
                                          size: 15, color: CelestialTheme.goldLight),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Add More Items',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: CelestialTheme.goldLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Order Type Selector Header
                    Text(
                      'ORDER TYPE',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Custom Segmented Order Type Pills
                    Row(
                      children: [
                        if (_profile?.allowTakeaway ?? true)
                          Expanded(
                            child: _buildOrderTypePill(
                              label: 'Pickup',
                              icon: '🛍️',
                              isSelected: selectedType == OrderType.takeaway,
                              onTap: () => setSheetState(() => selectedType = OrderType.takeaway),
                            ),
                          ),
                        if ((_profile?.allowTakeaway ?? true) && (_profile?.allowDineIn ?? true))
                          const SizedBox(width: 8),
                        if (_profile?.allowDineIn ?? true)
                          Expanded(
                            child: _buildOrderTypePill(
                              label: 'Dine-In',
                              icon: '🍽️',
                              isSelected: selectedType == OrderType.dineIn,
                              onTap: () => setSheetState(() => selectedType = OrderType.dineIn),
                            ),
                          ),
                        if (((_profile?.allowTakeaway ?? true) || (_profile?.allowDineIn ?? true)) &&
                            (_profile?.allowDelivery ?? true))
                          const SizedBox(width: 8),
                        if (_profile?.allowDelivery ?? true)
                          Expanded(
                            child: _buildOrderTypePill(
                              label: 'Delivery',
                              icon: '🛵',
                              isSelected: selectedType == OrderType.delivery,
                              onTap: () => setSheetState(() => selectedType = OrderType.delivery),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Polished Form Inputs with Friendly Inline Error Handling
                    _buildInputField(
                      controller: nameCtrl,
                      hint: 'Your Name *',
                      icon: Icons.person_outline_rounded,
                      errorText: nameError,
                      onChanged: (_) {
                        if (nameError != null) setSheetState(() => nameError = null);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildInputField(
                      controller: phoneCtrl,
                      hint: 'Mobile Phone Number *',
                      icon: Icons.phone_iphone_rounded,
                      keyboardType: TextInputType.phone,
                      errorText: phoneError,
                      onChanged: (_) {
                        if (phoneError != null) setSheetState(() => phoneError = null);
                      },
                    ),
                    const SizedBox(height: 10),

                    if (isDineIn) ...[
                      _buildInputField(
                        controller: tableCtrl,
                        hint: 'Table Number (e.g. Table 04) *',
                        icon: Icons.table_restaurant_outlined,
                        errorText: tableError,
                        onChanged: (_) {
                          if (tableError != null) setSheetState(() => tableError = null);
                        },
                      ),
                      const SizedBox(height: 10),
                    ] else if (isDelivery) ...[
                      _buildInputField(
                        controller: addressCtrl,
                        hint: 'Complete Delivery Address & Landmark *',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                        errorText: addressError,
                        onChanged: (_) {
                          if (addressError != null) setSheetState(() => addressError = null);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    _buildInputField(
                      controller: notesCtrl,
                      hint: 'Order notes / cutlery request (Optional)',
                      icon: Icons.edit_note_rounded,
                    ),
                    const SizedBox(height: 16),

                    // Payment Method Section
                    Text(
                      'PAYMENT METHOD',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPaymentPill(
                          label: 'Cash on Counter/Pickup',
                          icon: '💵',
                          isSelected: selectedPayment == PaymentMethod.cash,
                          onTap: () => setSheetState(() => selectedPayment = PaymentMethod.cash),
                        ),
                        _buildPaymentPill(
                          label: 'GCash',
                          icon: '📱',
                          isSelected: selectedPayment == PaymentMethod.mobilePay,
                          onTap: () => setSheetState(() => selectedPayment = PaymentMethod.mobilePay),
                        ),
                        if (isDelivery)
                          _buildPaymentPill(
                            label: 'Cash on Delivery (COD)',
                            icon: '🛵',
                            isSelected: selectedPayment == PaymentMethod.cod,
                            onTap: () => setSheetState(() => selectedPayment = PaymentMethod.cod),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Place Order CTA Button
                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: (_cart.isEmpty || isSubmitting) ? null : CelestialTheme.caramelGradient,
                        color: (_cart.isEmpty || isSubmitting) ? Colors.white.withValues(alpha: 0.10) : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: (_cart.isEmpty || isSubmitting)
                            ? null
                            : [
                                BoxShadow(
                                  color: CelestialTheme.caramelAccent.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed: (isSubmitting || _cart.isEmpty)
                            ? null
                            : () async {
                                final isCurrentlyOpen = _profile?.isOpen ?? true;
                                if (!isCurrentlyOpen) {
                                  _showClosedStoreModal();
                                  return;
                                }

                                if (_cart.isEmpty) {
                                  TopNotification.show(ctx,
                                      message: 'Your cart is empty. Please add items before placing an order.',
                                      type: TopNotificationType.warning);
                                  return;
                                }

                                final name = nameCtrl.text.trim();
                                final phone = phoneCtrl.text.trim();
                                final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
                                bool hasFormError = false;

                                if (name.isEmpty) {
                                  nameError = 'Please enter your name for the order';
                                  hasFormError = true;
                                } else if (name.length < 2) {
                                  nameError = 'Name must be at least 2 characters';
                                  hasFormError = true;
                                } else {
                                  nameError = null;
                                }

                                if (phone.isEmpty) {
                                  phoneError = 'Please enter your phone number';
                                  hasFormError = true;
                                } else if (digitsOnly.length < 7 || digitsOnly.length > 15) {
                                  phoneError = 'Please enter a valid mobile number (e.g. 0912 345 6789)';
                                  hasFormError = true;
                                } else {
                                  phoneError = null;
                                }

                                if (isDelivery) {
                                  final addr = addressCtrl.text.trim();
                                  if (addr.isEmpty) {
                                    addressError = 'Please enter your complete delivery address';
                                    hasFormError = true;
                                  } else if (addr.length < 5) {
                                    addressError = 'Please include complete street or nearby landmark';
                                    hasFormError = true;
                                  } else {
                                    addressError = null;
                                  }
                                } else {
                                  addressError = null;
                                }

                                if (isDineIn) {
                                  final tbl = tableCtrl.text.trim();
                                  if (tbl.isEmpty) {
                                    tableError = 'Please specify your table number';
                                    hasFormError = true;
                                  } else {
                                    tableError = null;
                                  }
                                } else {
                                  tableError = null;
                                }

                                if (hasFormError) {
                                  setSheetState(() {});
                                  TopNotification.show(
                                    ctx,
                                    message: 'Please review the highlighted fields above.',
                                    type: TopNotificationType.warning,
                                  );
                                  return;
                                }

                                setSheetState(() => isSubmitting = true);

                                try {
                                  final seq = DateTime.now().millisecondsSinceEpoch % 10000;
                                  final newOrder = Order(
                                    id: 'online_${DateTime.now().millisecondsSinceEpoch}',
                                    orderNumber: '#ON-$seq',
                                    orderType: selectedType,
                                    tableNumber: selectedType == OrderType.dineIn ? tableCtrl.text.trim() : null,
                                    customerName: name,
                                    customerPhone: phone,
                                    deliveryAddress: selectedType == OrderType.delivery ? addressCtrl.text.trim() : null,
                                    items: List.from(_cart),
                                    subtotal: _cartTotal,
                                    taxAmount: 0.0,
                                    taxRate: 0.0,
                                    totalAmount: _cartTotal,
                                    paymentMethod: selectedPayment,
                                    amountTendered: _cartTotal,
                                    status: OrderStatus.pending,
                                    createdAt: DateTime.now(),
                                    cashierName: 'Online Web Order',
                                    orderNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                                  );

                                  final success = await OnlineOrderService().submitCustomerOrder(
                                    storeId: _resolvedStoreId ?? widget.storeId,
                                    order: newOrder,
                                  );

                                  if (!sheetCtx.mounted) return;

                                  if (success) {
                                    Navigator.pop(sheetCtx);
                                    if (!mounted) return;
                                    _cart.clear();
                                    _startOrderTracking(newOrder, switchToTracker: true);
                                    setState(() {});
                                    _showOrderCelebrationDialog(newOrder);
                                  } else {
                                    setSheetState(() => isSubmitting = false);
                                    if (sheetCtx.mounted) {
                                      showDialog(
                                        context: sheetCtx,
                                        builder: (errCtx) => AlertDialog(
                                          backgroundColor: CelestialTheme.bgCard,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          title: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: CelestialTheme.roseAlert.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(Icons.wifi_off_rounded, color: CelestialTheme.roseAlert, size: 22),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  'Order Could Not Be Sent',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 17,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            'We were unable to connect with the café server to place your order. Please check your internet connection.\n\nDon\'t worry — your selected items, options, and special notes are still safely saved in your cart.',
                                            style: TextStyle(color: CelestialTheme.textMuted, fontSize: 13, height: 1.45),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(errCtx),
                                              child: Text('Review Cart', style: TextStyle(color: CelestialTheme.textMuted)),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.pop(errCtx);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: CelestialTheme.goldPrimary,
                                                foregroundColor: Colors.black,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              ),
                                              icon: const Icon(Icons.refresh_rounded, size: 16),
                                              label: const Text('Keep Cart & Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (sheetCtx.mounted) {
                                    setSheetState(() => isSubmitting = false);
                                    TopNotification.show(
                                      sheetCtx,
                                      message: 'Could not send order. Please check your network connection.',
                                      type: TopNotificationType.error,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: CelestialTheme.textMuted,
                          disabledBackgroundColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _cart.isEmpty
                                        ? 'Your Cart is Empty'
                                        : 'Place Order • ₱${_formatPrice(_cartTotal)}',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
      ),
    );
  }

  void _showOrderCelebrationDialog(Order order) {
    if (!mounted) return;

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    Timer? autoDismissTimer;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) {
        autoDismissTimer = Timer(const Duration(milliseconds: 5000), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.20),
                  blurRadius: 36,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing Celebratory Icon with scale/elastic pop & rotate
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: CelestialTheme.goldGradient,
                    boxShadow: [
                      BoxShadow(
                        color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.celebration_rounded,
                      color: CelestialTheme.bgDark,
                      size: 44,
                    ),
                  ),
                )
                    .animate()
                    .scale(begin: const Offset(0.2, 0.2), end: const Offset(1, 1), duration: 600.ms, curve: Curves.elasticOut)
                    .rotate(begin: -0.08, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 18),

                // Title
                Text(
                  'Order Sent to Kitchen!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 350.ms)
                    .slideY(begin: 0.2, end: 0, duration: 350.ms),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  'The barista has received your order and is reviewing it now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: CelestialTheme.textMuted,
                    height: 1.35,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 250.ms, duration: 350.ms),
                const SizedBox(height: 20),

                // Order Number Badge with Shimmer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ORDER NUMBER',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.orderNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.items.length} item${order.items.length == 1 ? '' : 's'} • ₱${_formatPrice(order.totalAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: CelestialTheme.creamSoft,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 350.ms, duration: 350.ms)
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 350.ms)
                    .shimmer(delay: 600.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 24),

                // Track Order Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      autoDismissTimer?.cancel();
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    icon: const Icon(Icons.radar_rounded, size: 20),
                    label: Text(
                      'Track Live Status',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 450.ms, duration: 350.ms)
                    .slideY(begin: 0.15, end: 0, duration: 350.ms),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      autoDismissTimer?.cancel();
      if (mounted) {
        setState(() {
          _isViewingTracker = true;
        });
      }
    });
  }

  Widget _buildOrderTypePill({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          gradient: isSelected ? CelestialTheme.caramelGradient : null,
          color: isSelected ? null : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? CelestialTheme.caramelAccent : CelestialTheme.borderWarm,
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: CelestialTheme.caramelAccent.withValues(alpha: 0.28),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : CelestialTheme.textLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPill({
    required String label,
    required String icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? CelestialTheme.goldPrimary.withValues(alpha: 0.15)
              : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? CelestialTheme.goldPrimary : CelestialTheme.borderWarm,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    final hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: CelestialTheme.textMuted.withValues(alpha: 0.7),
              fontSize: 12.5,
            ),
            prefixIcon: Icon(
              icon,
              color: hasError
                  ? CelestialTheme.roseAlert
                  : CelestialTheme.goldLight.withValues(alpha: 0.75),
              size: 18,
            ),
            filled: true,
            fillColor: CelestialTheme.bgCard,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? CelestialTheme.roseAlert.withValues(alpha: 0.85)
                    : CelestialTheme.borderWarm,
                width: hasError ? 1.2 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? CelestialTheme.roseAlert : CelestialTheme.goldPrimary,
                width: 1.4,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 12, color: CelestialTheme.roseAlert),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    errorText,
                    style: TextStyle(
                      color: CelestialTheme.roseAlert,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStoreNoticeBanner(bool isOpen, String? notice) {
    final cleanNotice = notice?.trim() ?? '';
    final hasNotice = cleanNotice.isNotEmpty;

    if (isOpen && !hasNotice) {
      return const SizedBox.shrink();
    }

    final isClosed = !isOpen;

    return InkWell(
      key: const ValueKey('store_notice_banner'),
      onTap: isClosed ? () => _showClosedStoreModal() : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isClosed
              ? CelestialTheme.roseAlert.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isClosed
                ? CelestialTheme.roseAlert.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: (isClosed ? CelestialTheme.roseAlert : CelestialTheme.goldPrimary)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isClosed ? CelestialTheme.roseAlert : CelestialTheme.goldPrimary)
                      .withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Icon(
                isClosed ? Icons.lock_clock_rounded : Icons.campaign_rounded,
                size: 20,
                color: isClosed ? CelestialTheme.roseAlert : CelestialTheme.goldLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isClosed ? 'ONLINE ORDERING IS PAUSED' : 'STORE ANNOUNCEMENT',
                          style: GoogleFonts.outfit(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: isClosed ? CelestialTheme.roseAlert : CelestialTheme.goldLight,
                            letterSpacing: 0.6,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isClosed
                              ? CelestialTheme.roseAlert.withValues(alpha: 0.18)
                              : CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isClosed
                                ? CelestialTheme.roseAlert.withValues(alpha: 0.35)
                                : CelestialTheme.goldPrimary.withValues(alpha: 0.30),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isClosed ? 'CLOSED' : 'NOTICE',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isClosed ? CelestialTheme.roseAlert : CelestialTheme.goldLight,
                              ),
                            ),
                            if (isClosed) ...[
                              const SizedBox(width: 3),
                              Icon(Icons.touch_app_rounded, size: 9, color: CelestialTheme.roseAlert),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isClosed
                        ? (hasNotice
                            ? cleanNotice
                            : 'The café is currently closed and not accepting online orders right now. You can still browse our menu items!')
                        : cleanNotice,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: isClosed && hasNotice ? FontWeight.bold : FontWeight.w500,
                      color: isClosed ? CelestialTheme.creamLight : CelestialTheme.textLight,
                      height: 1.3,
                    ),
                  ),
                  if (isClosed) ...[
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Checkout is temporarily paused until the store reopens.',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: CelestialTheme.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tap for details',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: CelestialTheme.roseAlert.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 8,
                              color: CelestialTheme.roseAlert.withValues(alpha: 0.85),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      style: TextStyle(color: CelestialTheme.textLight, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Search drinks, snacks, meals...',
        hintStyle: TextStyle(
          color: CelestialTheme.textSubtle.withValues(alpha: 0.8),
          fontSize: 12.5,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: CelestialTheme.textSubtle, size: 18),
        filled: true,
        fillColor: CelestialTheme.bgSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildStoreLogoWidget({double size = 44}) {
    Uint8List? directBytes;
    String? logoBase64;

    try {
      final pos = Provider.of<PosProvider>(context, listen: false);
      if (pos.customLogoBytes != null) {
        directBytes = pos.customLogoBytes;
      } else if (pos.customLogoBase64 != null && pos.customLogoBase64!.isNotEmpty) {
        logoBase64 = pos.customLogoBase64;
      }
    } catch (_) {}

    if (directBytes == null && (logoBase64 == null || logoBase64.isEmpty)) {
      logoBase64 = _profile?.storeLogoBase64;
    }

    if (directBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          directBytes,
          fit: BoxFit.cover,
          width: size,
          height: size,
          key: ValueKey('pos_direct_${directBytes.hashCode}'),
          errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(size: size),
        ),
      );
    }

    if (logoBase64 != null && logoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(logoBase64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: size,
            height: size,
            key: ValueKey(logoBase64.hashCode),
            errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(size: size),
          ),
        );
      } catch (_) {}
    }
    return _buildFallbackLogo(size: size);
  }

  Widget _buildFallbackLogo({double size = 44}) {
    try {
      final pos = Provider.of<PosProvider>(context, listen: false);
      if (pos.customLogoBytes != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            pos.customLogoBytes!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            errorBuilder: (context, error, stackTrace) => _buildDefaultAssetLogo(size: size),
          ),
        );
      }
    } catch (_) {}
    return _buildDefaultAssetLogo(size: size);
  }

  Widget _buildDefaultAssetLogo({double size = 44}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(
        'assets/images/Logo.png',
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Icon(Icons.coffee_rounded, color: CelestialTheme.goldLight, size: size * 0.5),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOpen
            ? CelestialTheme.emeraldReady.withValues(alpha: 0.12)
            : CelestialTheme.roseAlert.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: (isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert)
              .withValues(alpha: 0.28),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOpen ? 'OPEN' : 'PAUSED',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isOpen ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRecentOrdersDialog() async {
    final targetStore = _resolvedStoreId ?? widget.storeId;
    if (_recentOrders.isEmpty) {
      await _loadRecentOrderLocally(targetStore);
    }
    if (!mounted) return;

    if (_recentOrders.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.75),
        builder: (ctx) => Dialog(
          key: const ValueKey('no_active_orders_dialog'),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CelestialTheme.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: CelestialTheme.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Close',
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 30,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active Orders',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You don\'t have any active orders right now. Add items from our menu and place an order to track it live here!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: CelestialTheme.creamLight.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CelestialTheme.goldPrimary,
                      foregroundColor: CelestialTheme.primaryBtnText,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Browse Menu',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          return Dialog(
            key: const ValueKey('recent_orders_dialog'),
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Container(
              width: 520,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(dialogCtx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.receipt_long_rounded, color: CelestialTheme.goldLight, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Orders',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: CelestialTheme.textLight,
                                ),
                              ),
                              Text(
                                '${_recentOrders.length} ${_recentOrders.length == 1 ? "order" : "orders"} placed recently',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: CelestialTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: CelestialTheme.textMuted,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10, height: 1),

                  // Orders List
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shrinkWrap: true,
                      itemCount: _recentOrders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final order = _recentOrders[idx];
                        final meta = _getOrderStatusMeta(order);
                        final isCurrentlyTracking = _submittedOrder?.id == order.id;
                        final itemCount = order.items.fold<int>(0, (sum, it) => sum + it.quantity);
                        final itemsSummary = order.items.map((it) => '${it.quantity}x ${it.menuItem.name}').join(', ');

                        return Container(
                          key: ValueKey('recent_order_card_${order.id}'),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isCurrentlyTracking
                                ? CelestialTheme.goldPrimary.withValues(alpha: 0.08)
                                : CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isCurrentlyTracking
                                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.55)
                                  : CelestialTheme.borderWarm.withValues(alpha: 0.6),
                              width: isCurrentlyTracking ? 1.4 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Order Number, Type, and Status Badge
                              Row(
                                children: [
                                  Text(
                                    order.orderNumber,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: CelestialTheme.textLight,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      order.orderType.label,
                                      style: TextStyle(fontSize: 10.5, color: CelestialTheme.textMuted),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: meta.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: meta.color.withValues(alpha: 0.35), width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(meta.icon, size: 12, color: meta.color),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                meta.badge,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: meta.color,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Items preview & Total
                              Text(
                                '$itemCount item${itemCount > 1 ? "s" : ""}: $itemsSummary',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CelestialTheme.textMuted,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '₱${_formatPrice(order.totalAmount)} • ${order.paymentMethod.label}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: CelestialTheme.goldLight,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Dismiss from list
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 16),
                                        color: CelestialTheme.textSubtle,
                                        tooltip: 'Remove from recent orders',
                                        padding: const EdgeInsets.all(4),
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          _dismissRecentOrder(targetStore, order.id);
                                          setDialogState(() {});
                                          if (_recentOrders.isEmpty) {
                                            Navigator.of(ctx).pop();
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      // Action Button: View Details/Receipt for completed, Track Live for active
                                      if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) ...[
                                        InkWell(
                                          key: ValueKey('track_order_btn_${order.id}'),
                                          onTap: () {
                                            Navigator.of(ctx).pop();
                                            setState(() {
                                              _submittedOrder = order;
                                              _isViewingTracker = true;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: order.status == OrderStatus.completed
                                                  ? CelestialTheme.emeraldReady.withValues(alpha: 0.12)
                                                  : CelestialTheme.roseAlert.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: order.status == OrderStatus.completed
                                                    ? CelestialTheme.emeraldReady.withValues(alpha: 0.35)
                                                    : CelestialTheme.roseAlert.withValues(alpha: 0.35),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  order.status == OrderStatus.completed ? Icons.receipt_long_rounded : Icons.cancel_outlined,
                                                  size: 13,
                                                  color: order.status == OrderStatus.completed ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  order.status == OrderStatus.completed ? 'View Receipt' : 'Cancelled',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: order.status == OrderStatus.completed ? CelestialTheme.emeraldReady : CelestialTheme.roseAlert,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        InkWell(
                                          key: ValueKey('track_order_btn_${order.id}'),
                                          onTap: () {
                                            Navigator.of(ctx).pop();
                                            setState(() {
                                              _startOrderTracking(order, switchToTracker: true);
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              gradient: isCurrentlyTracking ? null : CelestialTheme.caramelGradient,
                                              color: isCurrentlyTracking ? CelestialTheme.goldPrimary.withValues(alpha: 0.18) : null,
                                              borderRadius: BorderRadius.circular(8),
                                              border: isCurrentlyTracking
                                                  ? Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4))
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isCurrentlyTracking ? 'Viewing Now' : 'Track Live',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isCurrentlyTracking ? CelestialTheme.goldLight : Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  isCurrentlyTracking ? Icons.check_rounded : Icons.arrow_forward_rounded,
                                                  size: 13,
                                                  color: isCurrentlyTracking ? CelestialTheme.goldLight : Colors.white,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Action: Order More
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              setState(() {
                                _isViewingTracker = false;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CelestialTheme.textLight,
                              side: BorderSide(color: CelestialTheme.borderWarm),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                            label: const Text('Order More Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderOrderBagButton() {
    final activeOrders = _recentOrders.where(
      (o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled,
    ).toList();
    final hasActiveOrder = activeOrders.isNotEmpty ||
        (_submittedOrder != null &&
            _submittedOrder!.status != OrderStatus.completed &&
            _submittedOrder!.status != OrderStatus.cancelled);
    final primaryOrder = (_submittedOrder != null &&
            _submittedOrder!.status != OrderStatus.completed &&
            _submittedOrder!.status != OrderStatus.cancelled)
        ? _submittedOrder!
        : (activeOrders.isNotEmpty ? activeOrders.first : (_recentOrders.isNotEmpty ? _recentOrders.first : null));
    final meta = primaryOrder != null ? _getOrderStatusMeta(primaryOrder) : null;
    final hasAnyOrder = _recentOrders.isNotEmpty || _submittedOrder != null;

    final String tooltipMsg = _recentOrders.length > 1
        ? 'Your Orders (${_recentOrders.length} in history)'
        : (primaryOrder != null
            ? (hasActiveOrder ? 'Track Active Order (${primaryOrder.orderNumber})' : 'Order History (${primaryOrder.orderNumber})')
            : 'Order History');

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        key: const ValueKey('header_order_tracker_btn'),
        onTap: () {
          if (_recentOrders.length > 1) {
            _showRecentOrdersDialog();
          } else if (hasActiveOrder && _submittedOrder != null) {
            setState(() {
              _isViewingTracker = true;
            });
          } else {
            _showRecentOrdersDialog();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: hasAnyOrder
                ? CelestialTheme.goldPrimary.withValues(alpha: 0.16)
                : CelestialTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasActiveOrder
                  ? CelestialTheme.goldPrimary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.14),
              width: 1.2,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: hasAnyOrder ? CelestialTheme.goldLight : CelestialTheme.textMuted,
                size: 21,
              ),
              if (_recentOrders.length > 1)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    key: const ValueKey('header_bag_count_badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: CelestialTheme.goldPrimary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: CelestialTheme.bgSurface,
                        width: 1.5,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    alignment: Alignment.center,
                    child: Text(
                      '${_recentOrders.length}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        height: 1.1,
                      ),
                    ),
                  ),
                )
              else if (hasActiveOrder && meta != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    key: const ValueKey('header_bag_active_indicator'),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: meta.color,
                      border: Border.all(
                        color: CelestialTheme.bgSurface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentOrderBanner(Order order) {
    final meta = _getOrderStatusMeta(order);
    final itemCount = order.totalItemCount;
    final itemText = '$itemCount ${itemCount == 1 ? 'item' : 'items'}';

    return Container(
      key: const ValueKey('recent_order_banner'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: CelestialTheme.goldPrimary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Status Icon Badge
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: meta.color.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(meta.icon, color: meta.color, size: 20),
          ),
          const SizedBox(width: 12),

          // Order summary info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Recent Order ${order.orderNumber}',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        meta.title,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: meta.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$itemText • ₱${_formatPrice(order.totalAmount)} • ${order.orderType.label}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: CelestialTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // View All Orders button if multiple
          if (_recentOrders.length > 1) ...[
            InkWell(
              key: const ValueKey('banner_view_all_orders_btn'),
              onTap: () => _showRecentOrdersDialog(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  'All (${_recentOrders.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textLight,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Track Order CTA
          InkWell(
            key: const ValueKey('banner_track_order_btn'),
            onTap: () {
              setState(() {
                _isViewingTracker = true;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: CelestialTheme.caramelGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Track Order',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Dismiss Button
          IconButton(
            tooltip: 'Dismiss order banner',
            icon: Icon(Icons.close_rounded, size: 16, color: CelestialTheme.textSubtle),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            onPressed: () {
              final targetStore = _resolvedStoreId ?? widget.storeId;
              _dismissRecentOrder(targetStore, order.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PosProvider? pos;
    try {
      pos = Provider.of<PosProvider>(context, listen: true);
    } catch (_) {}

    if (_submittedOrder != null && _isViewingTracker) {
      return _buildOrderTrackerView(pos);
    }

    final storeName = (pos != null && pos.storeName.isNotEmpty && pos.storeName != 'CELESTIAL CAFE')
        ? pos.storeName
        : ((_profile?.storeName != null && _profile!.storeName.trim().isNotEmpty)
            ? _profile!.storeName.trim()
            : 'Celestial Cafe');

    final storeTagline = (pos != null && pos.storeTagline.isNotEmpty)
        ? pos.storeTagline
        : ((_profile?.storeTagline != null && _profile!.storeTagline.trim().isNotEmpty)
            ? _profile!.storeTagline.trim()
            : 'Handcrafted Coffee & Treats');
    final isOpen = _profile?.isOpen ?? true;

    return Scaffold(
      backgroundColor: CelestialTheme.bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Store Owner Preview Banner (if previewing from POS)
            if (widget.previewMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: CelestialTheme.goldPrimary,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.preview_rounded, color: Colors.black, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Store Owner Preview Mode • Testing Customer View',
                      style: GoogleFonts.outfit(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black, size: 16),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // Store Header Card (Responsive: single-line on PC desktop, 2-line on mobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
              ),
              child: Center(
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isDesktopHeader = headerConstraints.maxWidth >= 840;

                      if (isDesktopHeader) {
                        return Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: _buildStoreLogoWidget(),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  storeName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.textLight,
                                  ),
                                ),
                                Text(
                                  storeTagline,
                                  style: TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                                ),
                              ],
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 340,
                              child: _buildSearchField(),
                            ),
                            const SizedBox(width: 12),
                            _buildHeaderOrderBagButton(),
                            const SizedBox(width: 12),
                            _buildStatusBadge(isOpen),
                          ],
                        );
                      }

                      // Mobile / Compact header
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: _buildStoreLogoWidget(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      storeName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.textLight,
                                      ),
                                    ),
                                    Text(
                                      storeTagline,
                                      style: TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildHeaderOrderBagButton(),
                              const SizedBox(width: 8),
                              _buildStatusBadge(isOpen),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildSearchField(),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),

            // Main Catalog Content (Constrained to maxWidth 1200 on PC screens)
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    children: [
                      // Active Recent Order Banner (only for live, uncompleted orders)
                      if (_submittedOrder != null &&
                          _submittedOrder!.status != OrderStatus.completed &&
                          _submittedOrder!.status != OrderStatus.cancelled)
                        _buildRecentOrderBanner(_submittedOrder!),

                      // Store Announcement & Closed Status Banner
                      _buildStoreNoticeBanner(isOpen, _profile?.customNotice),

                      // Best Seller Spotlight Banner (matching cashier hero spotlight)
                      if (_searchQuery.isEmpty && _bestSellerItem != null)
                        _buildBestSellerBanner(_bestSellerItem!, isOpen),

                      // Category Tabs Bar (matching cashier POS style)
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _categoryTabs.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, idx) {
                            final tab = _categoryTabs[idx];
                            final isSelected = _selectedCategory == tab.key;
                            return InkWell(
                              onTap: () => setState(() => _selectedCategory = tab.key),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: isSelected ? CelestialTheme.caramelGradient : null,
                                  color: isSelected ? null : CelestialTheme.bgCard,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? CelestialTheme.caramelAccent.withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.06),
                                    width: 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tab.icon.isNotEmpty) ...[
                                      Text(tab.icon, style: const TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                    ],
                                    Text(
                                      tab.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected
                                            ? CelestialTheme.bgDark
                                            : CelestialTheme.textLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Menu Items Grid (matching cashier POS item layout)
                      Expanded(
                        child: _isLoading
                            ? Center(child: CircularProgressIndicator(color: CelestialTheme.goldPrimary))
                            : _storeLoadError != null && _menuItems.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 72,
                                            height: 72,
                                            decoration: BoxDecoration(
                                              color: CelestialTheme.roseAlert.withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: CelestialTheme.roseAlert.withValues(alpha: 0.35)),
                                            ),
                                            child: Icon(
                                              Icons.wifi_off_rounded,
                                              size: 34,
                                              color: CelestialTheme.roseAlert,
                                            ),
                                          )
                                              .animate(onPlay: (c) => c.repeat(reverse: true))
                                              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1600.ms, curve: Curves.easeInOut),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Unable to Load Menu',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: CelestialTheme.textLight,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(maxWidth: 380),
                                            child: Text(
                                              _storeLoadError!,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: CelestialTheme.textMuted, fontSize: 13, height: 1.4),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          ElevatedButton.icon(
                                            onPressed: _loadStoreData,
                                            icon: const Icon(Icons.refresh_rounded, size: 18),
                                            label: Text(
                                              'Try Again',
                                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: CelestialTheme.goldPrimary,
                                              foregroundColor: CelestialTheme.primaryBtnText,
                                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : _filteredItems.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                                                ),
                                                child: Icon(
                                                  _menuItems.isEmpty ? Icons.restaurant_menu_rounded : Icons.search_off_rounded,
                                                  size: 30,
                                                  color: CelestialTheme.goldLight,
                                                ),
                                              )
                                                  .animate(onPlay: (c) => c.repeat(reverse: true))
                                                  .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1600.ms, curve: Curves.easeInOut),
                                              const SizedBox(height: 14),
                                              Text(
                                                _menuItems.isEmpty ? 'No Menu Items Available' : 'No Items Found',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: CelestialTheme.textLight,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _menuItems.isEmpty
                                                    ? 'This cafe has not published items yet.'
                                                    : 'Try searching for something else or pick a different category.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      int crossAxisCount = 3;
                                      double childAspectRatio = 0.64;
                                      double spacing = 8.0;
                                      EdgeInsets padding = EdgeInsets.fromLTRB(
                                        8,
                                        6,
                                        8,
                                        _cart.isNotEmpty ? 90 : 24,
                                      );

                                      if (constraints.maxWidth >= 1000) {
                                        // Desktop PC: 4 columns, aspect ratio 0.88 - cards are proportional, all buttons visible
                                        crossAxisCount = 4;
                                        childAspectRatio = 0.88;
                                        spacing = 14.0;
                                        padding = EdgeInsets.fromLTRB(
                                          16,
                                          8,
                                          16,
                                          _cart.isNotEmpty ? 90 : 28,
                                        );
                                      } else if (constraints.maxWidth >= 680) {
                                        // Tablet: 3 columns
                                        crossAxisCount = 3;
                                        childAspectRatio = 0.80;
                                        spacing = 10.0;
                                        padding = EdgeInsets.fromLTRB(
                                          12,
                                          8,
                                          12,
                                          _cart.isNotEmpty ? 90 : 24,
                                        );
                                      } else {
                                        // Mobile screens: 3 clean columns
                                        crossAxisCount = 3;
                                        childAspectRatio = 0.64;
                                        spacing = 8.0;
                                        padding = EdgeInsets.fromLTRB(
                                          8,
                                          6,
                                          8,
                                          _cart.isNotEmpty ? 90 : 24,
                                        );
                                      }

                                      final cartCounts = <String, int>{};
                                      for (final cItem in _cart) {
                                        cartCounts[cItem.menuItem.id] = (cartCounts[cItem.menuItem.id] ?? 0) + cItem.quantity;
                                      }

                                      return Scrollbar(
                                        controller: _scrollController,
                                        thumbVisibility: constraints.maxWidth >= 680,
                                        child: GridView.builder(
                                          key: ValueKey('menu_grid_$_selectedCategory'),
                                          controller: _scrollController,
                                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                                          padding: padding,
                                          scrollCacheExtent: const ScrollCacheExtent.pixels(600.0),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount,
                                            childAspectRatio: childAspectRatio,
                                            crossAxisSpacing: spacing,
                                            mainAxisSpacing: spacing,
                                          ),
                                          itemCount: _filteredItems.length,
                                          itemBuilder: (context, idx) {
                                            final item = _filteredItems[idx];
                                            return RepaintBoundary(
                                              child: ClientMenuItemCard(
                                                key: ValueKey('client_item_${item.id}'),
                                                item: item,
                                                inCartCount: cartCounts[item.id] ?? 0,
                                                isStoreOpen: isOpen,
                                                customNotice: _profile?.customNotice,
                                                onTap: () => _openCustomizationSheet(item),
                                              ),
                                            );
                                          },
                                        ).animate(key: ValueKey('grid_anim_$_selectedCategory')).fadeIn(duration: 180.ms),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // Bottom Floating Cart Bar with smooth animated size, price/count ticker, and glowing checkout
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: _cart.isEmpty
            ? const SizedBox(width: double.infinity, height: 0)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: CelestialTheme.bgCard,
                  border: Border(top: BorderSide(color: CelestialTheme.borderWarm)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Center(
                    heightFactor: 1.0,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Row(
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  '$_cartItemCount item${_cartItemCount == 1 ? '' : 's'} in cart',
                                  key: ValueKey('cart_count_$_cartItemCount'),
                                  style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, anim) => FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(anim),
                                    child: child,
                                  ),
                                ),
                                child: Text(
                                  '₱${_formatPrice(_cartTotal)}',
                                  key: ValueKey('cart_total_$_cartTotal'),
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.goldLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          if (isOpen)
                            ElevatedButton.icon(
                              onPressed: _openCheckoutSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CelestialTheme.goldPrimary,
                                foregroundColor: CelestialTheme.primaryBtnText,
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 4,
                                shadowColor: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
                              ),
                              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                              label: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            )
                                .animate()
                                .shimmer(delay: 400.ms, duration: 1200.ms, color: Colors.white.withValues(alpha: 0.25))
                          else
                            ElevatedButton.icon(
                              onPressed: () {
                                _showClosedStoreModal();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CelestialTheme.bgSurface,
                                foregroundColor: CelestialTheme.roseAlert,
                                side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.6), width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
                              label: const Text('Store Closed (Orders Paused)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildOrderTrackerView([PosProvider? pos]) {
    final order = _submittedOrder!;
    final status = order.status;

    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;
    Color statusColor;

    // Timeline step index: 0 = Sent, 1 = Confirmed, 2 = Preparing, 3 = Ready/Completed
    int currentStep = 0;

    switch (status) {
      case OrderStatus.pending:
        statusTitle = 'Order Sent • Waiting for Cashier Confirmation';
        statusSubtitle = 'The café has received your order. The cashier will review and confirm shortly.';
        statusIcon = Icons.hourglass_top_rounded;
        statusColor = CelestialTheme.amberBrewing;
        currentStep = 0;
        break;
      case OrderStatus.confirmed:
        final hasCashier = order.cashierName.isNotEmpty &&
            !order.cashierName.toLowerCase().contains('online') &&
            !order.cashierName.toLowerCase().contains('web');
        statusTitle = 'Order Confirmed by Cashier!';
        statusSubtitle = hasCashier
            ? 'Confirmed by cashier ${order.cashierName}. Kitchen is preparing your items (~${_profile?.estimatedPrepMinutes ?? 15} mins).'
            : 'Confirmed by cashier! Kitchen is preparing your items (~${_profile?.estimatedPrepMinutes ?? 15} mins).';
        statusIcon = Icons.thumb_up_alt_rounded;
        statusColor = CelestialTheme.goldPrimary;
        currentStep = 1;
        break;
      case OrderStatus.preparing:
        statusTitle = 'Kitchen is Preparing Your Order';
        statusSubtitle = 'Fresh ingredients are being crafted into your favorites (~${_profile?.estimatedPrepMinutes ?? 15} mins).';
        statusIcon = Icons.local_fire_department_rounded;
        statusColor = CelestialTheme.goldPrimary;
        currentStep = 2;
        break;
      case OrderStatus.ready:
        statusTitle = order.orderType == OrderType.delivery
            ? 'Order Ready for Delivery'
            : 'Your Order is Ready to Pickup on Cashier!';
        statusSubtitle = order.orderType == OrderType.delivery
            ? 'Please wait the order arrive. Courier is dispatching your order.'
            : 'Your order is ready to pickup on cashier. Please proceed to the counter.';
        statusIcon = Icons.check_circle_rounded;
        statusColor = CelestialTheme.emeraldReady;
        currentStep = 3;
        break;
      case OrderStatus.outForDelivery:
        statusTitle = 'Out for Delivery!';
        statusSubtitle = 'Please wait the order arrive. Rider is on the way to ${order.deliveryAddress ?? 'your address'}.';
        statusIcon = Icons.delivery_dining_rounded;
        statusColor = Colors.cyanAccent;
        currentStep = 3;
        break;
      case OrderStatus.completed:
        statusTitle = order.orderType == OrderType.delivery
            ? 'Order Completed'
            : 'Order Ready to Pickup on Cashier!';
        statusSubtitle = order.orderType == OrderType.delivery
            ? 'Please wait the order arrive if on transit, or verify receipt. Thank you!'
            : 'Your order is ready to pickup on cashier. Thank you for ordering!';
        statusIcon = Icons.verified_rounded;
        statusColor = CelestialTheme.emeraldReady;
        currentStep = 3;
        break;
      case OrderStatus.cancelled:
        statusTitle = 'Order Cancelled';
        statusSubtitle = 'This order was cancelled by the store.';
        statusIcon = Icons.cancel_outlined;
        statusColor = CelestialTheme.roseAlert;
        currentStep = 0;
        break;
    }

    final resolvedPos = pos ?? () {
      try {
        return Provider.of<PosProvider>(context, listen: false);
      } catch (_) {
        return null;
      }
    }();

    final storeName = (resolvedPos != null && resolvedPos.storeName.isNotEmpty && resolvedPos.storeName != 'CELESTIAL CAFE')
        ? resolvedPos.storeName
        : ((_profile?.storeName != null && _profile!.storeName.trim().isNotEmpty)
            ? _profile!.storeName.trim()
            : 'Celestial Cafe');

    final storeTagline = (resolvedPos != null && resolvedPos.storeTagline.isNotEmpty)
        ? resolvedPos.storeTagline
        : ((_profile?.storeTagline != null && _profile!.storeTagline.trim().isNotEmpty)
            ? _profile!.storeTagline.trim()
            : 'Handcrafted Coffee & Treats');

    return Scaffold(
      backgroundColor: CelestialTheme.bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CelestialTheme.bgCard,
                border: Border(bottom: BorderSide(color: CelestialTheme.borderWarm)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: _buildStoreLogoWidget(size: 42),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          storeName,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          storeTagline,
                          style: TextStyle(
                            fontSize: 11,
                            color: CelestialTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // All Orders button if customer placed multiple orders
                  if (_recentOrders.length > 1) ...[
                    InkWell(
                      key: const ValueKey('tracker_switch_orders_btn'),
                      onTap: () => _showRecentOrdersDialog(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_rounded, color: CelestialTheme.goldLight, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'Orders (${_recentOrders.length})',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: CelestialTheme.goldLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Live Pulse Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: status == OrderStatus.cancelled
                          ? CelestialTheme.roseAlert.withValues(alpha: 0.15)
                          : CelestialTheme.emeraldReady.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: status == OrderStatus.cancelled
                            ? CelestialTheme.roseAlert.withValues(alpha: 0.5)
                            : CelestialTheme.emeraldReady.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: status == OrderStatus.cancelled
                                ? CelestialTheme.roseAlert
                                : CelestialTheme.emeraldReady,
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(begin: const Offset(0.75, 0.75), end: const Offset(1.35, 1.35), duration: 800.ms)
                            .fade(begin: 0.45, end: 1.0, duration: 800.ms),
                        const SizedBox(width: 5),
                        Text(
                          status == OrderStatus.cancelled ? 'CANCELLED' : 'LIVE TRACKER',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: status == OrderStatus.cancelled
                                ? CelestialTheme.roseAlert
                                : CelestialTheme.emeraldReady,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor.withValues(alpha: 0.12),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.25),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 36),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.05, 1.05), duration: 1300.ms, curve: Curves.easeInOut),
                        const SizedBox(height: 16),

                        // Order Number Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          decoration: BoxDecoration(
                            color: CelestialTheme.goldPrimary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            order.orderNumber,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: CelestialTheme.goldLight,
                              letterSpacing: 1.2,
                            ),
                          ),
                        )
                            .animate()
                            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 400.ms, curve: Curves.easeOutBack)
                            .shimmer(delay: 600.ms, duration: 1500.ms, color: Colors.white.withValues(alpha: 0.25)),
                        const SizedBox(height: 12),

                        // Status Title
                        Text(
                          statusTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CelestialTheme.textLight,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Status Subtitle
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            statusSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: CelestialTheme.textMuted, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Timeline Progress Stepper (Except for cancelled orders)
                        if (status != OrderStatus.cancelled) ...[
                          _buildTimelineStepper(currentStep, order.orderType),
                          const SizedBox(height: 22),
                        ],

                        // Order Summary & Receipt Details Card
                        Container(
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: CelestialTheme.borderWarm, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_rounded, size: 16, color: CelestialTheme.goldLight),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Order Breakdown',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: CelestialTheme.textLight,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: CelestialTheme.caramelAccent.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        order.orderType.label,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.goldLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(color: CelestialTheme.borderWarm, height: 1),

                              // Items List
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    for (int i = 0; i < order.items.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          color: CelestialTheme.borderSubtle.withValues(alpha: 0.5),
                                          height: 14,
                                        ),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '${order.items[i].quantity}×',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: CelestialTheme.goldLight,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  order.items[i].menuItem.name,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: CelestialTheme.textLight,
                                                  ),
                                                ),
                                                if (order.items[i].customizations.isNotEmpty)
                                                  Text(
                                                    order.items[i].customizations.map((c) => c.optionName).join(', '),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: CelestialTheme.textMuted,
                                                    ),
                                                  ),
                                                if (order.items[i].notes != null && order.items[i].notes!.isNotEmpty)
                                                  Text(
                                                    'Note: ${order.items[i].notes}',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontStyle: FontStyle.italic,
                                                      color: CelestialTheme.creamSoft,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '₱${_formatPrice(order.items[i].totalPrice)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: CelestialTheme.goldLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Divider(color: CelestialTheme.borderWarm, height: 1),

                              // Customer & Fulfillment details
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _buildReceiptInfoRow('Customer', '${order.customerName} • ${order.customerPhone}'),
                                    if (order.tableNumber != null && order.tableNumber!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildReceiptInfoRow('Table Number', order.tableNumber!),
                                    ],
                                    if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildReceiptInfoRow('Delivery To', order.deliveryAddress!),
                                    ],
                                    const SizedBox(height: 8),
                                    _buildReceiptInfoRow('Payment Method', order.paymentMethod.label),
                                    if (order.orderNotes != null && order.orderNotes!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildReceiptInfoRow('Special Notes', order.orderNotes!),
                                    ],
                                    const SizedBox(height: 12),
                                    Divider(color: CelestialTheme.borderWarm, height: 1),
                                    const SizedBox(height: 12),

                                    // Total Row (Strictly No .00!)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Total Amount:',
                                          style: GoogleFonts.outfit(
                                            color: CelestialTheme.textLight,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '₱${_formatPrice(order.totalAmount)}',
                                          style: GoogleFonts.outfit(
                                            color: CelestialTheme.goldLight,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Real-Time Helper Note
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: CelestialTheme.bgCard.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: CelestialTheme.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.sync_rounded, size: 16, color: CelestialTheme.goldLight),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Live updating automatically as the cashier confirms your order.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: CelestialTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (order.status == OrderStatus.pending) ...[
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dCtx) => AlertDialog(
                                    backgroundColor: CelestialTheme.bgCard,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: Text(
                                      'Cancel Order?',
                                      style: GoogleFonts.outfit(
                                        color: CelestialTheme.roseAlert,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    content: Text(
                                      'Are you sure you want to cancel this pending order?',
                                      style: TextStyle(color: CelestialTheme.textMuted, fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dCtx, false),
                                        child: Text('Keep Order', style: TextStyle(color: CelestialTheme.textMuted)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(dCtx, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: CelestialTheme.roseAlert,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Yes, Cancel'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  final targetStore = _resolvedStoreId ?? widget.storeId;
                                  try {
                                    await OnlineOrderService().updateOrderStatus(
                                      storeId: targetStore,
                                      orderId: order.id,
                                      newStatus: OrderStatus.cancelled,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        order.status = OrderStatus.cancelled;
                                      });
                                      TopNotification.show(context, message: 'Order has been cancelled.', type: TopNotificationType.error);
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      TopNotification.show(
                                        context,
                                        message: 'Could not cancel order due to a connection issue. Please try again.',
                                        type: TopNotificationType.error,
                                      );
                                    }
                                  }
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: CelestialTheme.roseAlert.withValues(alpha: 0.6)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: Icon(Icons.close_rounded, size: 16, color: CelestialTheme.roseAlert),
                              label: Text(
                                'Cancel Order',
                                style: GoogleFonts.outfit(
                                  color: CelestialTheme.roseAlert,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (order.status == OrderStatus.completed) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: CelestialTheme.emeraldReady.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: CelestialTheme.emeraldReady.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.verified_rounded, color: CelestialTheme.emeraldReady, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Order Completed',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: CelestialTheme.emeraldReady,
                                        ),
                                      ),
                                      Text(
                                        'This order has been completed. Enjoy your items!',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: CelestialTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Back to Menu Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isViewingTracker = false;
                                if (_submittedOrder?.status == OrderStatus.completed ||
                                    _submittedOrder?.status == OrderStatus.cancelled) {
                                  _submittedOrder = null;
                                }
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.8), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: CelestialTheme.bgCard,
                            ),
                            icon: Icon(Icons.arrow_back_rounded, size: 16, color: CelestialTheme.goldLight),
                            label: Text(
                              'Back to Menu / Order Again',
                              style: GoogleFonts.outfit(
                                color: CelestialTheme.goldLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStepper(int currentStep, OrderType orderType) {
    final finalStepLabel = orderType == OrderType.delivery ? 'Delivery' : 'Ready';
    final steps = [
      (label: 'Order Sent', icon: Icons.send_rounded),
      (label: 'Confirmed', icon: Icons.thumb_up_alt_rounded),
      (label: 'Preparing', icon: Icons.coffee_maker_rounded),
      (label: finalStepLabel, icon: Icons.celebration_rounded),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CelestialTheme.borderWarm),
      ),
      child: Row(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i <= currentStep
                      ? CelestialTheme.goldPrimary
                      : CelestialTheme.borderSubtle,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                () {
                  Widget stepCircle = Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < currentStep
                          ? CelestialTheme.emeraldReady
                          : (i == currentStep
                              ? CelestialTheme.goldPrimary
                              : CelestialTheme.bgSurface),
                      border: Border.all(
                        color: i <= currentStep
                            ? CelestialTheme.goldLight
                            : CelestialTheme.borderWarm,
                        width: 1.5,
                      ),
                      boxShadow: i == currentStep
                          ? [
                              BoxShadow(
                                color: CelestialTheme.goldPrimary.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : (i < currentStep
                              ? [
                                  BoxShadow(
                                    color: CelestialTheme.emeraldReady.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null),
                    ),
                    child: Center(
                      child: Icon(
                        i < currentStep
                            ? Icons.check_rounded
                            : steps[i].icon,
                        size: 16,
                        color: i <= currentStep ? Colors.black : CelestialTheme.textMuted,
                      ),
                    ),
                  );

                  final isTestMode = WidgetsBinding.instance.runtimeType.toString().contains('Test');
                  if (i == currentStep && !isTestMode) {
                    stepCircle = stepCircle
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.08, 1.08), duration: 900.ms, curve: Curves.easeInOut);
                  }
                  return stepCircle;
                }(),
                const SizedBox(height: 6),
                Text(
                  steps[i].label,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: i == currentStep ? FontWeight.bold : FontWeight.w500,
                    color: i == currentStep
                        ? CelestialTheme.goldLight
                        : (i < currentStep ? CelestialTheme.creamSoft : CelestialTheme.textMuted),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: CelestialTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              color: CelestialTheme.textLight,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}
