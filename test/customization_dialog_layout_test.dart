import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/models/menu_item.dart';
import 'package:celestial_pos/widgets/customization_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Short options (Hot/Iced) use 2-column layout, long options use full-width row layout', (tester) async {
    final item = MenuItem(
      id: 'special_combo',
      name: 'Special Combo Meal',
      description: '2 pcs savory grilled pork barbeque & 3 pcs crispy lumpia shanghai',
      price: 99,
      category: ItemCategory.dinner,
      icon: '🍱',
      customizationGroups: [
        CustomizationGroup(
          id: 'temp',
          title: 'Temperature',
          isRequired: true,
          isMultiSelect: false,
          options: [
            const CustomizationOption(name: 'Hot'),
            const CustomizationOption(name: 'Iced'),
          ],
        ),
        CustomizationGroup(
          id: 'rice',
          title: 'Rice Choice',
          isRequired: true,
          isMultiSelect: false,
          options: [
            const CustomizationOption(name: 'Steamed White Rice'),
            const CustomizationOption(name: 'Garlic Fried Rice', extraPrice: 15),
            const CustomizationOption(name: 'Extra Steamed Rice', extraPrice: 20),
          ],
        ),
      ],
    );

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: CustomizationDialog(
              item: item,
              onAddToCart: (qty, customs, notes) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both groups rendered
    expect(find.text('Temperature'), findsOneWidget);
    expect(find.text('Rice Choice'), findsOneWidget);

    // Verify option text rendered
    expect(find.text('Hot'), findsOneWidget);
    expect(find.text('Iced'), findsOneWidget);
    expect(find.text('Steamed White Rice'), findsOneWidget);
    expect(find.text('Garlic Fried Rice'), findsOneWidget);
    expect(find.text('Extra Steamed Rice'), findsOneWidget);

    // Get the render box of "Hot" vs "Steamed White Rice"
    final hotFinder = find.ancestor(
      of: find.text('Hot'),
      matching: find.byType(SizedBox),
    ).first;
    final riceFinder = find.ancestor(
      of: find.text('Steamed White Rice'),
      matching: find.byType(SizedBox),
    ).first;

    final hotSize = tester.getSize(hotFinder);
    final riceSize = tester.getSize(riceFinder);

    // "Hot" is in 2-column layout (~175-195px), while "Steamed White Rice" is in full-width row (>300px)
    expect(riceSize.width, greaterThan(hotSize.width));
  });
}
