/// The parts Open Packaging Conventions files share (DOCX and XLSX): content types, relationships, properties.
library;

import 'export_model.dart';
import 'export_text.dart';

const kXmlDecl = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';

const _rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

/// The relationship types of [_rel], by short name.
String relType(String name) => '$_rel/$name';

const kCoreRelType = 'http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties';
const kCoreContentType = 'application/vnd.openxmlformats-package.core-properties+xml';
const kAppContentType = 'application/vnd.openxmlformats-officedocument.extended-properties+xml';

/// `[Content_Types].xml`: the default type of each extension and the type of each named part.
String contentTypes({required Map<String, String> defaults, required Map<String, String> overrides}) =>
    '$kXmlDecl<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '${defaults.entries.map((e) => '<Default Extension="${e.key}" ContentType="${e.value}"/>').join()}'
    '${overrides.entries.map((e) => '<Override PartName="${e.key}" ContentType="${e.value}"/>').join()}'
    '</Types>';

/// A `.rels` part from `(id, type, target)`.
String relationships(List<(String, String, String)> rels) =>
    '$kXmlDecl<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '${rels.map((r) => '<Relationship Id="${r.$1}" Type="${r.$2}" Target="${xmlEscape(r.$3, attribute: true)}"/>').join()}'
    '</Relationships>';

/// `docProps/core.xml`: title, author and the two dates (W3CDTF, UTC).
String coreProperties(ExportDoc d) =>
    '$kXmlDecl<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
    'xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" '
    'xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
    '<dc:title>${xmlEscape(d.title)}</dc:title>'
    '${d.subtitle.isEmpty ? '' : '<dc:subject>${xmlEscape(d.subtitle)}</dc:subject>'}'
    '<dc:creator>${xmlEscape(d.creator)}</dc:creator>'
    '<cp:contentStatus>${xmlEscape(d.status)}</cp:contentStatus>'
    '<dc:language>it-IT</dc:language>'
    '<cp:lastModifiedBy>${xmlEscape(d.creator)}</cp:lastModifiedBy>'
    '<dcterms:created xsi:type="dcterms:W3CDTF">${utcStamp(d.created)}</dcterms:created>'
    '<dcterms:modified xsi:type="dcterms:W3CDTF">${utcStamp(d.modified)}</dcterms:modified>'
    '</cp:coreProperties>';

/// `docProps/app.xml`: the application, and the brand as the company.
String appProperties(ExportDoc d) =>
    '$kXmlDecl<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    '<Application>Daylex</Application><DocSecurity>0</DocSecurity><ScaleCrop>false</ScaleCrop>'
    '${d.brand.isEmpty ? '' : '<Company>${xmlEscape(d.brand)}</Company>'}'
    '<LinksUpToDate>false</LinksUpToDate><SharedDoc>false</SharedDoc><HyperlinksChanged>false</HyperlinksChanged>'
    '</Properties>';
