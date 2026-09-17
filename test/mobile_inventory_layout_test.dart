import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:celestial_pos/providers/pos_provider.dart';
import 'package:celestial_pos/screens/inventory_screen.dart';

void main() {
  testWidgets('InventoryScreen mobile layout renders item cards cleanly without overflow', (tester) async {
    // Set a typical mobile screen size (360x740)
    tester.view.physicalSize = const Size(360 * 2.0, 740 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final posProvider = PosProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<PosProvider>.value(
        value: posProvider,
        child: const MaterialApp(
          home: InventoryScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify header renders
    expect(find.text('Menu & Price Control'), findsOneWidget);

    // Verify stock and price are rendered
    expect(find.byType(Switch), findsWidgets);
    expect(find.text('IN STOCK'), findsWidgets);
    expect(find.text('+20'), findsWidgets);
    expect(find.text('Edit'), findsWidgets);

    // Test Delete confirmation dialog appears
    final deleteButton = find.byIcon(Icons.delete_outline_rounded).first;
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete Item?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Item?'), findsNothing);
  });
}
