import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper_agent/core/platform/frame_recovery.dart';

/// What the system tells the app about its window, sent the way the engine sends it.
Future<void> _systemSays(WidgetTester tester, AppLifecycleState state) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(state.toString()),
      (_) {},
    );

/// A wake signal from the native runner (screen unlocked, computer woke up).
Future<void> _runnerSays(WidgetTester tester, String reason) =>
    tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      FrameRecovery.channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('visible', reason)),
      (_) {},
    );

void main() {
  late List<String> log;
  Iterable<String> recoveries() => log.where((line) => line.startsWith('recovered'));

  Future<void> start(WidgetTester tester) async {
    log = [];
    await tester.pumpWidget(FrameRecovery(log: log.add, child: const SizedBox.expand()));
    // Hidden, as macOS leaves the app after a screen lock when it never says the window is back.
    await _systemSays(tester, AppLifecycleState.inactive);
    await _systemSays(tester, AppLifecycleState.hidden);
    expect(tester.binding.framesEnabled, isFalse, reason: 'a hidden app draws nothing');
  }

  tearDown(() => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

  group('drawing comes back after sleep or lock even when the system never says the window is back', () {
    testWidgets('the mouse moving over the window', (tester) async {
      await start(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(const Offset(20, 20));

      expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
      expect(tester.binding.framesEnabled, isTrue);
      expect(tester.binding.hasScheduledFrame, isTrue, reason: 'the stale frame is replaced at once');
      expect(recoveries().single, contains('hidden'));
      await mouse.removePointer();
    });

    testWidgets('a key pressed', (tester) async {
      await start(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);

      expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
      expect(tester.binding.framesEnabled, isTrue);
    });

    testWidgets('the screen unlocked, as the native runner reports it', (tester) async {
      await start(tester);
      await _runnerSays(tester, 'unlock');

      expect(tester.binding.lifecycleState, AppLifecycleState.resumed);
      expect(tester.binding.framesEnabled, isTrue);
      expect(recoveries().single, contains('unlock'));
    });
  });

  testWidgets('a window the system reports correctly is left alone', (tester) async {
    log = [];
    await tester.pumpWidget(FrameRecovery(log: log.add, child: const SizedBox.expand()));
    await _systemSays(tester, AppLifecycleState.inactive);
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await _runnerSays(tester, 'unlock');

    expect(tester.binding.lifecycleState, AppLifecycleState.inactive, reason: 'only a hidden or paused app is wrong');
    expect(recoveries(), isEmpty);
  });
}
