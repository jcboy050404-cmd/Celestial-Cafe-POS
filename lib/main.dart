import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/pos_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/kds_screen.dart';
import 'screens/orders_history_screen.dart';
import 'screens/pending_orders_screen.dart';
import 'screens/pos_screen.dart';
import 'theme/celestial_theme.dart';
import 'widgets/header_bar.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PosProvider.repairCorruptedStorage();
  runApp(const CelestialCafePosApp());
}

class CelestialCafePosApp extends StatelessWidget {
  const CelestialCafePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PosProvider()),
      ],
      child: Consumer<PosProvider>(
        builder: (context, posProvider, _) {
          return MaterialApp(
            title: 'Celestial Cafe POS',
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
            home: const MainWorkstationScaffold(),
          );
        },
      ),
    );
  }
}

class MainWorkstationScaffold extends StatefulWidget {
  const MainWorkstationScaffold({super.key});

  @override
  State<MainWorkstationScaffold> createState() => _MainWorkstationScaffoldState();
}

class _MainWorkstationScaffoldState extends State<MainWorkstationScaffold> {
  bool _isScrolled = false;

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final screens = const [
      PosScreen(),
      PendingOrdersScreen(),
      KdsScreen(),
      OrdersHistoryScreen(),
      InventoryScreen(),
      AnalyticsScreen(),
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
                  index: posProvider.currentNavIndex,
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
                  selectedIndex: posProvider.currentNavIndex,
                  onDestinationSelected: (index) => posProvider.setNavIndex(index),
                  destinations: [
                    const NavigationDestination(
                      icon: Icon(Icons.point_of_sale_outlined),
                      selectedIcon: Icon(Icons.point_of_sale_rounded),
                      label: 'POS',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: posProvider.pendingCustomerOrders.isNotEmpty,
                        backgroundColor: CelestialTheme.goldPrimary,
                        label: Text(
                          '${posProvider.pendingCustomerOrders.length}',
                          style: const TextStyle(color: CelestialTheme.bgDark, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        child: const Icon(Icons.hourglass_top_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: posProvider.pendingCustomerOrders.isNotEmpty,
                        backgroundColor: CelestialTheme.goldPrimary,
                        label: Text(
                          '${posProvider.pendingCustomerOrders.length}',
                          style: const TextStyle(color: CelestialTheme.bgDark, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        child: const Icon(Icons.hourglass_top_rounded),
                      ),
                      label: 'Pending',
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: posProvider.activeKdsOrders.isNotEmpty,
                        backgroundColor: CelestialTheme.amberBrewing,
                        label: Text(
                          '${posProvider.activeKdsOrders.length}',
                          style: const TextStyle(color: CelestialTheme.bgDark, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        child: const Icon(Icons.coffee_maker_outlined),
                      ),
                      selectedIcon: Badge(
                        isLabelVisible: posProvider.activeKdsOrders.isNotEmpty,
                        backgroundColor: CelestialTheme.amberBrewing,
                        label: Text(
                          '${posProvider.activeKdsOrders.length}',
                          style: const TextStyle(color: CelestialTheme.bgDark, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        child: const Icon(Icons.coffee_maker_rounded),
                      ),
                      label: 'KDS',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: 'History',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: 'Stock',
                    ),
                    const NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: 'Insights',
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
