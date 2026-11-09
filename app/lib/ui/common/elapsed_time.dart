import 'dart:async';

import 'package:flutter/material.dart';

const _elapsedRefresh = Duration(seconds: 1);

/// Observed time, never an estimate of completion.
class ElapsedTime extends StatefulWidget {
  const ElapsedTime({
    super.key,
    required this.startedAt,
    required this.running,
    this.seconds = 0,
    this.style,
  });
  final DateTime? startedAt;
  final bool running;
  final int seconds;
  final TextStyle? style;
  @override
  State<ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<ElapsedTime> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(ElapsedTime oldWidget) {
    super.didUpdateWidget(oldWidget);
    _listen();
  }

  void _listen() {
    _timer?.cancel();
    if (widget.running) {
      _timer = Timer.periodic(
        _elapsedRefresh,
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.running && widget.startedAt != null
        ? DateTime.now().difference(widget.startedAt!).inSeconds.clamp(0, 86400)
        : widget.seconds;
    return ExcludeSemantics(
      child: Text(elapsedLabel(seconds), style: widget.style),
    );
  }
}

String elapsedLabel(int seconds) =>
    seconds < 60 ? '$seconds s' : '${seconds ~/ 60} min ${seconds % 60} s';
