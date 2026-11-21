import 'document_export/csv_test.dart' as csv;
import 'document_export/docx_test.dart' as docx;
import 'document_export/export_parts_test.dart' as parts;
import 'document_export/formats_test.dart' as formats;
import 'document_export/odf_test.dart' as odf;
import 'document_export/text_formats_test.dart' as text_formats;
import 'document_export/xlsx_test.dart' as xlsx;

/// `scripts/test.sh` runs the `test/*_test.dart` files; the export tests live in `test/document_export/`, one file per
/// family of formats, and this one runs them all.
void main() {
  parts.main();
  formats.main();
  docx.main();
  odf.main();
  xlsx.main();
  csv.main();
  text_formats.main();
}
