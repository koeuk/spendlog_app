import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/api_client.dart';

/// Downloads the report file over the API and hands it to the system share
/// sheet — save to Files, send to Telegram, print, whatever the phone offers.
///
/// Not offered on web: a browser tab already has the real website, and the
/// sandbox has no filesystem to save into anyway.
bool get canExportReports => !kIsWeb;

Future<void> exportReport(
  BuildContext context, {
  required String format,
  required String period,
  String? anchor,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final response = await ApiClient.instance.dio.get<List<int>>(
      '/reports/export/$format',
      queryParameters: {'period': period, 'at': ?anchor},
      options: Options(responseType: ResponseType.bytes),
    );

    // The server names the file in Content-Disposition; fall back to something
    // honest if a proxy strips it.
    final header = response.headers.value('content-disposition') ?? '';
    final match = RegExp('filename="?([^";]+)"?').firstMatch(header);
    final filename = match?.group(1) ?? 'spendlog-report.$format';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(response.data!);

    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(apiErrorMessage(e, fallback: 'Could not export the report.'))),
    );
  }
}
