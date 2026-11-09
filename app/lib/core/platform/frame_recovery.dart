import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'diagnostic_log.dart';

/// Keeps the window drawing after the screen locks, the computer sleeps or the app sits behind others.
///
/// A hidden or paused app draws nothing, and draws again only once the system says the window is back.
/// Some systems never say it (macOS after a screen lock with the app in front): the window keeps its last
/// frame, blurred, and seems deaf to mouse and keyboard. Input, or a wake signal from the native runner on
/// [channel], while the app believes it is hidden is proof it is not: the state the system failed to send
/// is delivered here, through the same channel, and a frame is forced. At worst a minimised app draws.
///
/// Everything the system says about the window, and every recovery, goes to [log] (the window diagnostic
/// log by default), with frames that were asked for and never shown, for the freezes this does not cure.
class FrameRecovery extends StatefulWidget {
  const FrameRecovery({super.key, required this.child, this.log});

  /// The native runners send `visible` here, with the reason, when the window may be back unannounced.
  static const channel = MethodChannel('paper_agent/window');

  /// How long a frame may take to reach the screen before the log says it never did.
  static const frameDeadline = Duration(seconds: 5);

  final Widget child;
  final void Function(String line)? log;

  @override
  State<FrameRecovery> createState() => _FrameRecoveryState();
}

class _FrameRecoveryState extends State<FrameRecovery> with WidgetsBindingObserver {
  void _log(String line) => (widget.log ?? DiagnosticLog.window?.add)?.call(line);

  Timer? _frameWatch;
  DateTime? _lastWatch;

  @override
  void initState() {
    super.initState();
    _log(kIsWeb ? 'start: web' : 'start: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    WidgetsBinding.instance.addObserver(this);
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    HardwareKeyboard.instance.addHandler(_onKey);
    FrameRecovery.channel.setMethodCallHandler(_onRunner);
  }

  @override
  void dispose() {
    FrameRecovery.channel.setMethodCallHandler(null);
    HardwareKeyboard.instance.removeHandler(_onKey);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    WidgetsBinding.instance.removeObserver(this);
    _frameWatch?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _log('lifecycle: ${state.name}');

  void _onPointer(PointerEvent event) {
    _recover('mouse');
    if (event is PointerDownEvent) _watchFrames('click');
  }

  bool _onKey(KeyEvent event) {
    _recover('keyboard');
    if (event is KeyDownEvent) _watchFrames('key');
    return false;
  }

  Future<void> _onRunner(MethodCall call) async {
    if (call.method != 'visible') return;
    final reason = '${call.arguments ?? 'runner'}';
    _log('window: $reason');
    _recover(reason);
    _watchFrames(reason, always: true);
  }

  /// Delivers the `resumed` the system did not send, if the app still believes it is hidden or paused.
  void _recover(String why) {
    final state = SchedulerBinding.instance.lifecycleState;
    if (state == null || (state != AppLifecycleState.hidden && state != AppLifecycleState.paused)) return;
    _log('recovered from ${state.name}: $why');
    ServicesBinding.instance.channelBuffers.push(
      SystemChannels.lifecycle.name,
      SystemChannels.lifecycle.codec.encodeMessage(AppLifecycleState.resumed.toString()),
      (_) {},
    );
    SchedulerBinding.instance.scheduleForcedFrame();
  }

  /// Logs a frame asked for after [why] that was not built or not shown within [FrameRecovery.frameDeadline]:
  /// what tells a stalled app from a stalled screen. Input is checked at most once a minute.
  void _watchFrames(String why, {bool always = false}) {
    final now = DateTime.now();
    if (_frameWatch != null) return;
    if (!always && _lastWatch != null && now.difference(_lastWatch!) < const Duration(minutes: 1)) return;
    _lastWatch = now;
    final scheduler = SchedulerBinding.instance;
    var built = false;
    var shown = false;
    void onShown(List<FrameTiming> _) => shown = true;
    scheduler.addTimingsCallback(onShown);
    scheduler.addPostFrameCallback((_) => built = true);
    scheduler.scheduleFrame();
    _frameWatch = Timer(FrameRecovery.frameDeadline, () {
      _frameWatch = null;
      scheduler.removeTimingsCallback(onShown);
      if (built && shown) return;
      _log('no frame ${built ? 'shown' : 'built'} ${FrameRecovery.frameDeadline.inSeconds} s after $why '
          '(lifecycle ${scheduler.lifecycleState?.name}, frames ${scheduler.framesEnabled ? 'on' : 'off'})');
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
