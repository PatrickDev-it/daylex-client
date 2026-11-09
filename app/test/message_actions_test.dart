import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:paper_agent/ui/chat/message_actions.dart';
import 'package:paper_agent/ui/common/time_format.dart';

import 'test_app.dart';

void main() {
  test('stamps: time today, the day before, the date after', () {
    final now = DateTime(2026, 10, 5, 18);
    final l = itL10n;
    expect(shortStamp(l, DateTime(2026, 10, 5, 9, 7), now), '09:07');
    expect(shortStamp(l, DateTime(2026, 10, 4, 23, 59), now), 'ieri 23:59');
    expect(shortStamp(l, DateTime(2026, 9, 28, 14, 32), now), '28 set, 14:32');
    expect(shortStamp(l, DateTime(2025, 12, 31, 8, 0), now), '31 dic 2025, 08:00');
    expect(fullStamp(l, DateTime(2026, 10, 5, 14, 32, 7)), '5 ott 2026, 14:32:07');
  });

  testWidgets('hovering a message shows copy and time; copy puts its text on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Center(
            child: MessageActions(
              text: 'Il testo della risposta',
              time: DateTime.now(),
              alignEnd: false,
              child: const SizedBox(width: 300, height: 60, child: Text('Il testo della risposta')),
            ),
          ),
        ),
      ),
    );

    double opacity() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(opacity(), 0);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Il testo della risposta')));
    await tester.pumpAndSettle();
    expect(opacity(), 1);

    await tester.tap(find.byIcon(LucideIcons.copy));
    await tester.pump();
    expect(copied, 'Il testo della risposta');
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
