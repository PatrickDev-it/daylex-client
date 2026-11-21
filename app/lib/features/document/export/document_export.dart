/// Every file format a document can leave the app in, and the one entry point that writes the ones Dart writes here.
/// The PDF is drawn by the renderer; the others are plain, synchronous functions of the document, so a caller may run
/// them on an isolate.
library;

import 'dart:typed_data';

import '../model/document.dart';
import 'csv_writer.dart';
import 'docx_writer.dart';
import 'html_writer.dart';
import 'md_writer.dart';
import 'ods_writer.dart';
import 'odt_writer.dart';
import 'rtf_writer.dart';
import 'txt_writer.dart';
import 'xlsx_writer.dart';

enum ExportFormat {
  pdf('pdf', 'application/pdf', 'PDF'),
  docx('docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'Word (.docx)'),
  odt('odt', 'application/vnd.oasis.opendocument.text', 'LibreOffice Writer (.odt)'),
  rtf('rtf', 'application/rtf', 'Rich Text (.rtf)'),
  txt('txt', 'text/plain; charset=utf-8', 'Testo semplice (.txt)'),
  md('md', 'text/markdown; charset=utf-8', 'Markdown (.md)'),
  html('html', 'text/html; charset=utf-8', 'Pagina web (.html)'),
  xlsx('xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'Excel (.xlsx)'),
  ods('ods', 'application/vnd.oasis.opendocument.spreadsheet', 'LibreOffice Calc (.ods)'),
  csv('csv', 'text/csv; charset=utf-8', 'CSV (.csv)');

  const ExportFormat(this.extension, this.mimeType, this.label);

  /// The file extension, without the dot.
  final String extension;
  final String mimeType;

  /// What the lawyer reads in the menu.
  final String label;

  /// The file name of [doc] in this format: the PDF's name (the title, made safe for a file system) with this extension.
  String fileNameOf(PaperDocument doc) {
    final pdf = doc.fileName;
    return '${pdf.substring(0, pdf.length - '.pdf'.length)}.$extension';
  }
}

/// The bytes of [doc] in [format]. The PDF is not written here (it is drawn by the page renderer): asking for it is a
/// programming error, and fails loudly rather than returning something that looks like a PDF.
Uint8List encodeDocument(PaperDocument doc, ExportFormat format) => switch (format) {
  ExportFormat.pdf => throw ArgumentError.value(format, 'format', 'The PDF is drawn by the page renderer, not encoded here'),
  ExportFormat.docx => encodeDocx(doc),
  ExportFormat.odt => encodeOdt(doc),
  ExportFormat.rtf => encodeRtf(doc),
  ExportFormat.txt => encodeTxt(doc),
  ExportFormat.md => encodeMd(doc),
  ExportFormat.html => encodeHtml(doc),
  ExportFormat.xlsx => encodeXlsx(doc),
  ExportFormat.ods => encodeOds(doc),
  ExportFormat.csv => encodeCsv(doc),
};
