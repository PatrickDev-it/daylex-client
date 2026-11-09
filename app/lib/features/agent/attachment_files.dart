import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'domain/agent_protocol.dart';

/// What the case file reads, by extension: documents, signed copies (.p7m) and scans.
const _mimeByType = {
  'pdf': 'application/pdf',
  'p7m': 'application/pkcs7-mime',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'txt': 'text/plain',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
};

final attachableTypes = List<String>.unmodifiable(_mimeByType.keys);

/// What follows the last dot of [name], lower case; empty when the name has no dot (it has no extension).
String _typeOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// The file's own name. XFile.name splits on one separator only: "Temp/nota.txt" from a path that mixes both.
String _nameOf(XFile f) =>
    f.path.isEmpty ? f.name : f.path.split(RegExp(r'[\\/]')).last;

/// The files the lawyer picks in the system dialog; [label] names the filter.
Future<List<XFile>> pickAttachable(String label) => openFiles(
  acceptedTypeGroups: [XTypeGroup(label: label, extensions: attachableTypes)],
);

/// The files picked or dropped that were not attached, by name, for each reason.
class LeftOut {
  const LeftOut({
    this.wrongType = const [],
    this.tooLarge = const [],
    this.unreadable = const [],
  });

  /// A type the case file does not read.
  final List<String> wrongType;

  /// Past the [maxAttachmentBytes] the chat holds at once, with what it already holds.
  final List<String> tooLarge;

  /// The system would not give them (open in another program, no permission, gone), files or folders.
  final List<String> unreadable;

  bool get isEmpty =>
      wrongType.isEmpty && tooLarge.isEmpty && unreadable.isEmpty;
}

/// Files picked or dropped on the window, folders opened, read while their bytes fit in [room]: those the case
/// file takes, and what was left out and why. A file that cannot be read leaves out that file, never the others.
Future<(List<AgentAttachment>, LeftOut)> readAttachable(
  List<XFile> files, {
  int room = maxAttachmentBytes,
  bool deferBytes = false,
  int maxFiles = maxCaseDocuments,
}) async {
  final picked = <AgentAttachment>[];
  final wrongType = <String>[];
  final tooLarge = <String>[];
  final unreadable = <String>[];
  for (final f in expandFolders(files, onUnreadable: unreadable.add)) {
    final name = _nameOf(f);
    if (!_mimeByType.containsKey(_typeOf(name))) {
      wrongType.add(name);
      continue;
    }
    try {
      if (deferBytes && f.path.isNotEmpty && await File(f.path).exists()) {
        if (picked.length >= maxFiles || await f.length() > maxFileBytes) {
          tooLarge.add(name);
          continue;
        }
        picked.add(
          AgentAttachment(
            name: name,
            mimeType: f.mimeType ?? mimeFor(name),
            bytes: Uint8List(0),
            localPath: f.path,
          ),
        );
        continue;
      }
      // The size first: a file past the room is never read into memory.
      final size = await f.length();
      if (picked.length >= maxFiles || size > room || size > maxFileBytes) {
        tooLarge.add(name);
        continue;
      }
      final bytes = await f.readAsBytes();
      if (bytes.length > room || bytes.length > maxFileBytes) {
        tooLarge.add(name); // it grew since
        continue;
      }
      room -= bytes.length;
      picked.add(
        AgentAttachment(
          name: name,
          mimeType: f.mimeType ?? mimeFor(name),
          bytes: bytes,
        ),
      );
    } on FileSystemException {
      unreadable.add(name);
    }
  }
  return (
    picked,
    LeftOut(wrongType: wrongType, tooLarge: tooLarge, unreadable: unreadable),
  );
}

/// A dropped folder stands for every file in it, subfolders included, in name order; links are not followed.
/// A folder the system will not list goes to [onUnreadable], by name.
Iterable<XFile> expandFolders(
  List<XFile> files, {
  void Function(String name)? onUnreadable,
}) sync* {
  for (final f in files) {
    if (f.path.isEmpty || !FileSystemEntity.isDirectorySync(f.path)) {
      yield f;
      continue;
    }
    final List<File> inside;
    try {
      inside = Directory(f.path)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .toList();
    } on FileSystemException {
      onUnreadable?.call(_nameOf(f));
      continue;
    }
    inside.sort((a, b) => a.path.compareTo(b.path));
    yield* inside.map((e) => XFile(e.path));
  }
}

String mimeFor(String name) =>
    _mimeByType[_typeOf(name)] ?? 'application/octet-stream';
