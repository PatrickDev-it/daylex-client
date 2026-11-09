import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/l10n.dart';

/// Agent output may open public web pages, never local files or app commands.
Uri? publicWebUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !{'https', 'http'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty ||
      !uri.hasAuthority) {
    return null;
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (!host.contains('.') ||
      host.contains(':') ||
      RegExp(r'^[\d.]+$').hasMatch(host) ||
      ['.localhost', '.local', '.internal', '.test'].any(host.endsWith)) {
    return null;
  }
  return uri;
}

Future<void> openWebLink(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Platform failures are actionable feedback, never unhandled async errors.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.l10n.webLinkUnavailable)));
  }
}
