import 'dart:async';

import '../../l10n/l10n.dart';
import 'data/http_agent_client.dart';
import 'domain/agent_protocol.dart';

/// The attachments of one chat being read into its case file on the server. Each chip goes uploading → ready
/// (read), failed (not read: sent with the run instead, which reads it or says why it cannot) or back to plain
/// (no case file: the bytes go with the run).
class CaseFileUploads {
  final _jobs = <Future<void>>{};
  Future<void> _tail = Future.value();
  static final _lanes = [Future<void>.value(), Future<void>.value()];
  static int _nextLane = 0;
  final _cancelled = <Object>{};

  static Future<T> _bounded<T>(Future<T> Function() operation) {
    final lane = _nextLane++ % _lanes.length;
    final result = _lanes[lane].then((_) => operation());
    _lanes[lane] = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void cancel(AgentAttachment attachment) =>
      _cancelled.add(attachment.identity);

  /// Case-file names these uploads added (removing the chip removes them).
  final _added = <String>{};

  /// A send waits while this is true: a long scan may still be in OCR.
  bool get busy => _jobs.isNotEmpty;

  Future<void> settled() => Future.wait([..._jobs]);

  /// Reads [a] into the case file of [sessionId]; [show] gets each state of its chip, [log] what the server read,
  /// both worded in [l10n].
  void upload(
    AgentClient client,
    String sessionId,
    AgentAttachment a, {
    required AppLocalizations l10n,
    required void Function(AgentAttachment) show,
    required void Function(String) log,
  }) {
    show(a.withStatus(AttachmentStatus.uploading));
    late final Future<void> job;
    job = _tail
        .then(
          (_) => _bounded(
            () async => _cancelled.contains(a.identity)
                ? null
                : await client.uploadAttachment(sessionId, a),
          ),
        )
        .then((card) async {
          if (_cancelled.contains(a.identity)) {
            if (card != null && card.isNew) {
              await client.deleteAttachment(sessionId, card.name);
            }
            return;
          }
          if (card == null) return show(a);
          if (card.isNew) _added.add(card.name);
          show(
            a.withStatus(
              card.readable ? AttachmentStatus.ready : AttachmentStatus.failed,
              serverName: card.name,
              summary: card.summary(l10n),
            ),
          );
          log('${card.name}: ${card.summary(l10n)}');
        })
        .catchError((Object e) {
          if (!_cancelled.contains(a.identity)) {
            show(
              a.withStatus(
                AttachmentStatus.failed,
                summary: describeFailure(l10n, e),
              ),
            );
          } else {
            log(describeFailure(l10n, e));
          }
        })
        .whenComplete(() {
          _jobs.remove(job);
          _cancelled.remove(a.identity);
        });
    _jobs.add(job);
    _tail = job;
  }

  /// Whether [name] was added by these uploads, forgetting it: a chip picked by mistake leaves the case file
  /// too, or the agent would keep reading it. A file the case file already had stays.
  bool release(String name) => _added.remove(name);
}
