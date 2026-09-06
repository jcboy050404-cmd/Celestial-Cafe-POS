import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/widgets/top_notification.dart';
import 'package:celestial_pos/widgets/menu_item_card.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TopNotification Overlay Tests', () {
    testWidgets('TopNotification.show displays message and icon at top of screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: TopNotification.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TopNotification.showSuccess(
                      context,
                      'Order #1 completed & handed over!',
                    );
                  },
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to show top notification
      await tester.tap(find.text('Show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify notification message is displayed
      expect(find.text('Order #1 completed & handed over!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Verify close button dismisses notification
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Order #1 completed & handed over!'), findsNothing);
    });

    testWidgets('TopNotification.showOrderHandedOver renders UNDO button and triggers callback', (tester) async {
      bool undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: TopNotification.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TopNotification.showOrderHandedOver(
                      context,
                      orderNumber: '1',
                      onUndo: () {
                        undoCalled = true;
                      },
                    );
                  },
                  child: const Text('Show Order Complete'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Order Complete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify message and UNDO button
      expect(find.text('Order 1 completed & handed over!'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      // Tap UNDO
      await tester.tap(find.text('UNDO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(undoCalled, isTrue);
      expect(find.text('Order 1 completed & handed over!'), findsNothing);
    });

    testWidgets('TopNotification auto-dismisses after duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: TopNotification.navigatorKey,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    TopNotification.show(
                      context,
                      message: 'Auto dismiss test',
                      duration: const Duration(milliseconds: 500),
                    );
                  },
                  child: const Text('Show Auto'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Auto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Auto dismiss test'), findsOneWidget);

      // Advance past duration + animation
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Auto dismiss test'), findsNothing);
    });
  });

  group('Sold Out Label Tests', () {
    testWidgets('MenuItemCard displays SOLD OUT overlay when item is out of stock', (tester) async {
      final unavailableItem = MenuItem(
        id: 'test_sold_out_item',
        name: 'Caramel Macchiato',
        description: 'Test coffee',
        price: 140,
        category: ItemCategory.coffee,
        icon: '☕',
        inStock: false,
      );

      final provider = PosProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: provider,
            child: Scaffold(
              body: SizedBox(
                width: 300,
                height: 350,
                child: MenuItemCard(item: unavailableItem),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SOLD OUT overlay appears (and old OUT OF STOCK does not)
      expect(find.text('SOLD OUT'), findsOneWidget);
      expect(find.text('OUT OF STOCK'), findsNothing);
    });
  });
}
