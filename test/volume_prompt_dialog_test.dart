import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:celestial_pos/widgets/volume_prompt_dialog.dart';

void main() {
  testWidgets('VolumePromptDialog displays without close button and dismisses on Volume Up key',
      (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await VolumePromptDialog.show(context);
              },
              child: const Text('Open Volume Modal'),
            ),
          ),
        ),
      ),
    );

    // Tap button to open VolumePromptDialog
    await tester.tap(find.text('Open Volume Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify modal elements are displayed
    expect(find.text('Please Turn Up Your Volume'), findsOneWidget);
    expect(find.text('AUDIO VOLUME NOTICE'), findsOneWidget);
    expect(find.text('VOL UP (+)'), findsOneWidget);
    expect(find.text('VOL DOWN (-)'), findsOneWidget);

    // Verify there are NO close or cancel buttons
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text('Close'), findsNothing);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Dismiss'), findsNothing);
    expect(find.text('OK'), findsNothing);

    // Simulate pressing physical Volume Up key
    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeUp);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog is closed
    expect(find.text('Please Turn Up Your Volume'), findsNothing);
    expect(dialogResult, isTrue);
  });

  testWidgets('VolumePromptDialog dismisses on Volume Down key',
      (WidgetTester tester) async {
    bool? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await VolumePromptDialog.show(context);
              },
              child: const Text('Open Volume Modal'),
            ),
          ),
        ),
      ),
    );

    // Tap button to open VolumePromptDialog
    await tester.tap(find.text('Open Volume Modal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Please Turn Up Your Volume'), findsOneWidget);

    // Simulate pressing physical Volume Down key
    await tester.sendKeyEvent(LogicalKeyboardKey.audioVolumeDown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog is closed
    expect(find.text('Please Turn Up Your Volume'), findsNothing);
    expect(dialogResult, isTrue);
  });
}
