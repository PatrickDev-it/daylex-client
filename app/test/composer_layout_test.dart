import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:paper_agent/app.dart';

import 'test_app.dart';

/// The composer and its document menu fit at common window sizes: any
/// RenderFlex overflow is reported as a FlutterError, which fails the test.
void main() {
  // The real Inter metrics: the test font is wider and would size the menu differently.
  setUpAll(() async {
    final inter = FontLoader('Inter');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
    }
    await inter.load();
  });

  for (final size in const [Size(1480, 900), Size(900, 640), Size(640, 560)]) {
    testWidgets('document menu opens without overflow at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ProviderScope(child: PaperAgentApp()));
      await tester.pump(const Duration(seconds: 1));

      final picker = find.descendant(
        of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_DocumentPicker'),
        matching: find.byIcon(LucideIcons.chevronDown),
      );
      expect(picker, findsOneWidget);
      await tester.tap(picker);
      await tester.pump(const Duration(milliseconds: 500));

      final item = find.text(itL10n.composerNoDocumentCreate);
      expect(item, findsOneWidget);
      // Hovering restyles the item while the menu keeps the width it opened with.
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(item));
      await tester.pump(const Duration(milliseconds: 500));
      // Neither the model nor the server address is shown to the lawyer.
      expect(find.textContaining('Qwen'), findsNothing);
      expect(find.textContaining('127.0.0.1'), findsNothing);
    });
  }
}
