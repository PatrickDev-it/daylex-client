/// The ZIP container of DOCX, XLSX, ODT and ODS, built the way each standard asks.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Entries in the order they are added; the first one is the first in the file (ODF needs `mimetype` there).
class ZipPackage {
  /// Every entry carries [modified], so the same document gives the same bytes (and a stable hash) every time.
  ZipPackage(DateTime modified) : _modified = _clamp(modified);

  final DateTime _modified;
  final _archive = Archive();

  /// ZIP stores local time with a year from 1980 to 2107.
  static DateTime _clamp(DateTime d) {
    final u = d.toUtc();
    if (u.year < 1980) return DateTime.utc(1980);
    if (u.year > 2107) return DateTime.utc(2107, 12, 31);
    return u;
  }

  void addText(String name, String content) => addBytes(name, utf8.encode(content));

  void addBytes(String name, List<int> bytes) => _archive.add(ArchiveFile.bytes(name, bytes));

  /// An entry written as it is, not deflated: the ODF `mimetype`, which a reader sniffs at a fixed offset.
  void addStored(String name, List<int> bytes) => _archive.add(ArchiveFile.noCompress(name, bytes.length, bytes));

  Uint8List toBytes() => ZipEncoder().encodeBytes(_archive, level: DeflateLevel.defaultCompression, modified: _modified);
}
