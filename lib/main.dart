import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'models/app_feature.dart';
import 'models/order.dart';
import 'providers/pos_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/food_costing_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/orders_history_screen.dart';
import 'screens/pos_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/customer_online_order_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_backup_service.dart';
import 'theme/celestial_theme.dart';
import 'widgets/header_bar.dart';
import 'widgets/online_order_confirm_dialog.dart';
import 'widgets/top_notification.dart';
import 'widgets/trial_expired_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}
  PosProvider.repairCorruptedStorage();
  runApp(const JcPosApp());
}

class JcPosApp extends StatelessWidget {
  final AuthService? authService;
  final PosProvider? posProvider;

  const JcPosApp({
    super.key,
    this.authService,
    this.posProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (authService != null)
          ChangeNotifierProvider<AuthService>.value(value: authService!)
        else
          ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        if (posProvider != null)
          ChangeNotifierProvider<PosProvider>.value(value: posProvider!)
        else
          ChangeNotifierProvider<PosProvider>(create: (_) => PosProvider()),
      ],
      child: Consumer2<AuthService, PosProvider>(
        builder: (context, authService, posProvider, _) {
          // Whenever the signed-in user changes, reload POS data for that account.
          // Guard against infinite callback loops by checking if already loaded.
          final user = authService.currentUser;
          final storeEmail = (user != null && user.isCashier && user.ownerEmail != null && user.ownerEmail!.isNotEmpty)
              ? user.ownerEmail!
              : (user?.email ?? '');
          if (authService.isLoggedIn && storeEmail.isNotEmpty) {
            if (posProvider.currentUserEmail != storeEmail) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                posProvider.loadForUser(storeEmail);
                posProvider.updateCurrentUser(authService.currentUser);
              });
            }
          } else if (!authService.isLoggedIn) {
            if (posProvider.currentUserEmail != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                posProvider.clearUserSession();
              });
            }
          }

          return MaterialApp(
            navigatorKey: TopNotification.navigatorKey,
            title: 'JC POS SYSTEM',
            debugShowCheckedModeBanner: false,
            theme: CelestialTheme.themeData,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(posProvider.uiScale),
                ),
                child: child!,
              );
            },
            onGenerateRoute: (settings) {
              final name = settings.name ?? '';
              final uri = Uri.tryParse(name) ?? Uri();
              if (uri.path == '/order' || name.startsWith('/order') || name.startsWith('#/order')) {
                final storeId = uri.queryParameters['store'] ?? 'default_store';
                final table = uri.queryParameters['table'];
                return MaterialPageRoute(
                  builder: (_) => CustomerOnlineOrderScreen(
                    storeId: storeId,
                    initialTable: table,
                  ),
                );
              }
              return null;
            },
            home: _resolveInitialScreen(authService),
          );
        },
      ),
    );
  }

  Widget _resolveInitialScreen(AuthService authService) {
    if (kIsWeb) {
      final base = Uri.base;
      final fragment = base.fragment;
      if (base.path == '/order' || fragment.startsWith('/order')) {
        final params = fragment.contains('?')
            ? Uri.splitQueryString(fragment.split('?').last)
            : base.queryParameters;
        final storeId = params['store'] ?? 'default_store';
        final table = params['table'];
        return CustomerOnlineOrderScreen(
          storeId: storeId,
          initialTable: table,
        );
      }
    }
    return authService.isLoggedIn
        ? const MainWorkstationScaffold()
        : const LoginScreen();
  }
}

typedef CelestialCafePosApp = JcPosApp;

class MainWorkstationScaffold extends StatefulWidget {
  const MainWorkstationScaffold({super.key});

  @override
  State<MainWorkstationScaffold> createState() => _MainWorkstationScaffoldState();
}

class _MainWorkstationScaffoldState extends State<MainWorkstationScaffold> {
  bool _isScrolled = false;
  int _lastNavIndex = 0;

  @override
  void initState() {
    super.initState();
    // Dismiss any leftover dialogs or overlays from login/registration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      while (TopNotification.navigatorKey.currentState?.canPop() ?? false) {
        TopNotification.navigatorKey.currentState?.pop();
      }

      final auth = Provider.of<AuthService>(context, listen: false);
      if (!auth.isAdmin && auth.currentUser?.isTrialExpired == true) {
        TrialExpiredDialog.show(context);
      }

      // Asynchronously refresh cloud license and restore Pro backup if available
      auth.refreshUserLicenseFromCloud().then((_) async {
        if (!mounted) return;
        final updatedAuth = Provider.of<AuthService>(context, listen: false);
        if (!updatedAuth.isAdmin && updatedAuth.currentUser?.isTrialExpired == true) {
          TrialExpiredDialog.show(context);
        } else if (updatedAuth.isPro || updatedAuth.isAdmin) {
          // PRO / Admin: Automatically check if Cloud Backup exists and restore
          try {
            final user = updatedAuth.currentUser;
            if (user != null) {
              final backup = await CloudBackupService().fetchProBackup(user.email);
              if (backup != null && mounted) {
                final pos = Provider.of<PosProvider>(context, listen: false);
                await pos.restoreFromProCloudBackup(backup);
              }
              if (mounted) {
                final pos = Provider.of<PosProvider>(context, listen: false);
                await pos.syncMenuFromCloud();
              }
            }
          } catch (_) {}
        }
      }).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final auth = Provider.of<AuthService>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Verify if current active tab is permitted; fallback to POS (0) if restricted
    final isCurrentTabAllowed = switch (posProvider.currentNavIndex) {
      1 => auth.isFeatureEnabled(AppFeature.orderHistory),
      2 => auth.isFeatureEnabled(AppFeature.inventory),
      3 => auth.isFeatureEnabled(AppFeature.analytics),
      4 => auth.isFeatureEnabled(AppFeature.foodCosting),
      _ => true,
    };
    if (!isCurrentTabAllowed && posProvider.currentNavIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) posProvider.setNavIndex(0);
      });
    }

    if (_lastNavIndex != posProvider.currentNavIndex) {
      _lastNavIndex = posProvider.currentNavIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
        }
      });
    }

    final screens = const [
      PosScreen(),
      OrdersHistoryScreen(),
      InventoryScreen(),
      AnalyticsScreen(),
      FoodCostingScreen(),
    ];

    final availableDestinations = <({int targetIndex, Widget icon, Widget selectedIcon, String label})>[
      (
        targetIndex: 0,
        icon: const Icon(Icons.point_of_sale_outlined),
        selectedIcon: const Icon(Icons.point_of_sale_rounded),
        label: 'POS',
      ),
      if (auth.isFeatureEnabled(AppFeature.orderHistory))
        (
          targetIndex: 1,
          icon: Badge(
            isLabelVisible: posProvider.pendingOnlineOrdersCount > 0,
            label: Text('${posProvider.pendingOnlineOrdersCount}'),
            child: const Icon(Icons.receipt_long_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: posProvider.pendingOnlineOrdersCount > 0,
            label: Text('${posProvider.pendingOnlineOrdersCount}'),
            child: const Icon(Icons.receipt_long_rounded),
          ),
          label: 'History',
        ),
      if (auth.isFeatureEnabled(AppFeature.inventory))
        (
          targetIndex: 2,
          icon: const Icon(Icons.inventory_2_outlined),
          selectedIcon: const Icon(Icons.inventory_2_rounded),
          label: 'Stock',
        ),
      if (auth.isFeatureEnabled(AppFeature.analytics))
        (
          targetIndex: 3,
          icon: const Icon(Icons.insights_outlined),
          selectedIcon: const Icon(Icons.insights_rounded),
          label: 'Insights',
        ),
      if (auth.isFeatureEnabled(AppFeature.foodCosting))
        (
          targetIndex: 4,
          icon: const Icon(Icons.calculate_outlined),
          selectedIcon: const Icon(Icons.calculate_rounded),
          label: 'Costing',
        ),
    ];

    int activeBottomIndex = availableDestinations.indexWhere(
      (d) => d.targetIndex == posProvider.currentNavIndex,
    );
    if (activeBottomIndex < 0) activeBottomIndex = 0;

    return Scaffold(
      backgroundColor: CelestialTheme.bgDark,
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical) {
              final scrolled = notification.metrics.pixels > 10;
              if (scrolled != _isScrolled) {
                setState(() {
                  _isScrolled = scrolled;
                });
              }
            }
            return false;
          },
          child: Column(
            children: [
              // Top Persistent Header Bar with Liquid Glass Scroll Animation
              HeaderBar(isScrolled: _isScrolled),

              // Pending Online Orders Global Alert Banner (When on POS or any tab except Order History)
              if (posProvider.pendingOnlineOrdersCount > 0 && posProvider.currentNavIndex != 1)
                Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          CelestialTheme.goldPrimary.withValues(alpha: 0.9),
                          CelestialTheme.caramelAccent.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_active_rounded, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🔔 ${posProvider.pendingOnlineOrdersCount} NEW ONLINE ORDER${posProvider.pendingOnlineOrdersCount > 1 ? 'S' : ''} RECEIVED!',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            final pendingList = posProvider.incomingOnlineOrders
                                .where((o) => o.status == OrderStatus.pending)
                                .toList();
                            if (pendingList.isNotEmpty) {
                              OnlineOrderConfirmDialog.show(context, pendingList.first);
                            } else if (posProvider.incomingOnlineOrders.isNotEmpty) {
                              OnlineOrderConfirmDialog.show(context, posProvider.incomingOnlineOrders.first);
                            } else {
                              posProvider.setNavIndex(1);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            foregroundColor: CelestialTheme.emeraldReady,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          icon: Icon(Icons.check_circle_rounded, size: 14, color: CelestialTheme.emeraldReady),
                          label: const Text('Confirm Order', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        TextButton(
                          onPressed: () {
                            posProvider.setNavIndex(1);
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.black45,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: const Text('View All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),

              // Screen Content
              Expanded(
                child: IndexedStack(
                  index: posProvider.currentNavIndex.clamp(0, screens.length - 1),
                  children: screens,
                ),
              ),
            ],
          ),
        ),
      ),
      // Mobile Bottom Navigation Bar
      bottomNavigationBar: isMobile
          ? Container(
              decoration: BoxDecoration(
                color: CelestialTheme.bgSurface,
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  indicatorColor: CelestialTheme.goldPrimary.withValues(alpha: 0.2),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.goldLight,
                      );
                    }
                    return GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                      color: CelestialTheme.textMuted,
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return IconThemeData(color: CelestialTheme.goldPrimary, size: 22);
                    }
                    return IconThemeData(color: CelestialTheme.textMuted, size: 20);
                  }),
                ),
                child: NavigationBar(
                  height: 66,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  backgroundColor: Colors.transparent,
                  selectedIndex: activeBottomIndex.clamp(0, availableDestinations.length - 1),
                  onDestinationSelected: (index) {
                    if (index >= 0 && index < availableDestinations.length) {
                      posProvider.setNavIndex(availableDestinations[index].targetIndex);
                    }
                  },
                  destinations: availableDestinations
                      .map((d) => NavigationDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon,
                            label: d.label,
                          ))
                      .toList(),
                ),
              ),
            )
          : null,
    );
  }
}