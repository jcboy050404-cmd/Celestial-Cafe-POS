import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/pos_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/food_costing_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/login_screen.dart';
import 'screens/orders_history_screen.dart';
import 'screens/pos_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'theme/celestial_theme.dart';
import 'widgets/header_bar.dart';
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
          return MaterialApp(
            navigatorKey: TopNotification.navigatorKey,
            title: 'JC POS System',
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
            home: authService.isLoggedIn
                ? const MainWorkstationScaffold()
                : const LoginScreen(),
          );
        },
      ),
    );
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

      // Asynchronously refresh cloud license in background
      auth.refreshUserLicenseFromCloud().then((_) {
        if (mounted) {
          final updatedAuth = Provider.of<AuthService>(context, listen: false);
          if (!updatedAuth.isAdmin && updatedAuth.currentUser?.isTrialExpired == true) {
            TrialExpiredDialog.show(context);
          }
        }
      }).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

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
                      return const IconThemeData(color: CelestialTheme.goldPrimary, size: 22);
                    }
                    return const IconThemeData(color: CelestialTheme.textMuted, size: 20);
                  }),
                ),
                child: NavigationBar(
                  height: 66,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  backgroundColor: Colors.transparent,
                  selectedIndex: posProvider.currentNavIndex.clamp(0, 4),
                  onDestinationSelected: (index) => posProvider.setNavIndex(index),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale_rounded),
                      label: 'POS',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: 'History',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: 'Stock',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: 'Insights',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calculate_outlined),
                      selectedIcon: Icon(Icons.calculate_rounded),
                      label: 'Costing',
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
