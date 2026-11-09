import 'dart:typed_data';

import 'document.dart';

class DocumentReviewFailure implements Exception {
  const DocumentReviewFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class DocumentReviewer {
  Future<DocumentReview> reviewDocument(
    PaperDocument document, {
    Uint8List? pdf,
  });
}

class LanguageIssue {
  LanguageIssue.fromJson(Map<String, dynamic> json)
    : page = json['page'] as int,
      text = json['text'] as String,
      message = json['message'] as String,
      key = '${json['path']}:${json['offset']}:${json['rule']}:${json['text']}',
      spelling = json['spelling'] == true,
      blocking = json['blocking'] as bool,
      protected = json['protected'] as bool;

  final int page;
  final String text;
  final String message;
  final String key;
  final bool spelling;
  final bool blocking;
  final bool protected;
}

class DocumentReview {
  DocumentReview.fromJson(Map<String, dynamic> json)
    : revision = json['revision'] as String,
      complete = json['complete'] == true,
      issues = (json['issues'] as List)
          .map((v) => LanguageIssue.fromJson(v as Map<String, dynamic>))
          .toList(),
      pdfComplete = (json['pdf'] as Map?)?['complete'] == true,
      pdfIssues = List<String>.from((json['pdf'] as Map?)?['issues'] ?? []);

  final String revision;
  final bool complete;
  final List<LanguageIssue> issues;
  final bool pdfComplete;
  final List<String> pdfIssues;
  bool get canExport => canExportWith(const {});

  bool canExportWith(Set<String> confirmed) =>
      complete &&
      pdfComplete &&
      pdfIssues.isEmpty &&
      !issues.any(
        (i) => i.blocking && !confirmed.contains('$revision:${i.key}'),
      );

  void requireExport([Set<String> confirmed = const {}]) {
    if (!canExportWith(confirmed)) {
      throw const DocumentReviewFailure(
        'Esportazione sospesa: completa la verifica e correggi i rilievi nel documento.',
      );
    }
  }
}
