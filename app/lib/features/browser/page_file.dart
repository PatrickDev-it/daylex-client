import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'engine/browser_page.dart';
import 'web_address.dart';

/// The file a page becomes for the chat (rfc/052 §7): a PDF as it is; a web page as HTML that opens with where it
/// came from and when, [note] in the lawyer's words, then the page's own text.
({String name, Uint8List bytes}) pageFile(PageCapture capture, DateTime at, {required String note}) {
  switch (capture) {
    case PdfCapture(:final bytes):
      return (name: pageFileName(capture.title, capture.url, at, 'pdf'), bytes: bytes);
    case HtmlCapture(:final body):
      const escape = HtmlEscape(HtmlEscapeMode.attribute);
      final url = escape.convert(capture.url.toString());
      final title = escape.convert(capture.title);
      final html =
          '<!DOCTYPE html>\n<html lang="it"><head><meta charset="utf-8"><title>$title</title>'
          '<meta name="daylex-source" content="$url"><meta name="daylex-captured" content="${at.toIso8601String()}">'
          '</head><body>\n<p>${escape.convert(note)}<br><a href="$url">$url</a></p><hr>\n$body\n</body></html>\n';
      return (name: pageFileName(capture.title, capture.url, at, 'html'), bytes: utf8.encode(html));
  }
}

/// Writes [file] where the chat sends it from, as a file dropped on the window: a folder of its own in the system's
/// temporary folder, so the name stays the page's. Returns its path. The chat reads it when it is sent; the folders
/// of pages kept longer ago than [keptPagesFor] go, once a run, after this one is written: the lawyer never waits on
/// the sweep.
Future<String> savePageFile(({String name, Uint8List bytes}) file) async {
  final root = Directory.systemTemp;
  final dir = await root.createTemp(_pagePrefix);
  final saved = File('${dir.path}${Platform.pathSeparator}${file.name}');
  await saved.writeAsBytes(file.bytes, flush: true);
  if (!_swept) {
    _swept = true;
    unawaited(sweepPageFiles(root, DateTime.now().subtract(keptPagesFor)));
  }
  return saved.path;
}

/// How long a page kept for the chat waits on disk for the chat to be sent.
const keptPagesFor = Duration(days: 7);

const _pagePrefix = 'daylex-page-';
var _swept = false;

/// Deletes the folders [savePageFile] made in [temp] that were last changed before [before]; one that cannot go
/// now is left for the next run.
Future<void> sweepPageFiles(Directory temp, DateTime before) async {
  try {
    await for (final entry in temp.list(followLinks: false)) {
      if (entry is! Directory || !entry.path.split(RegExp(r'[\\/]')).last.startsWith(_pagePrefix)) continue;
      try {
        if ((await entry.stat()).modified.isBefore(before)) await entry.delete(recursive: true);
      } on FileSystemException {
        // In use, or no longer there.
      }
    }
  } on FileSystemException {
    // The temporary folder cannot be listed: nothing to sweep.
  }
}
