import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class EmailService {
  EmailService._();
  static final EmailService instance = EmailService._();

  static const _channel = MethodChannel('com.controlasistencia.control_asistencia/email');
  static const _gmailPackage = 'com.google.android.gm';

  Future<void> sendViaGmail({
    required File file,
    required String subject,
    required String body,
  }) async {
    if (!await file.exists()) {
      throw Exception('Archivo no encontrado');
    }

    if (Platform.isAndroid) {
      final uri = await _channel.invokeMethod<String>('getContentUri', file.path);
      if (uri != null && uri.isNotEmpty) {
        final intent = AndroidIntent(
          action: 'android.intent.action.SEND',
          package: _gmailPackage,
          type: _mimeType(file.path),
          arguments: {
            'android.intent.extra.SUBJECT': subject,
            'android.intent.extra.TEXT': body,
            'android.intent.extra.STREAM': uri,
          },
          flags: <int>[Flag.FLAG_GRANT_READ_URI_PERMISSION],
        );
        await intent.launch();
        return;
      }
    }

    throw Exception('No se pudo abrir Gmail. Verifique que este instalado.');
  }

  String _mimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (ext == '.pdf') return 'application/pdf';
    if (ext == '.csv') return 'text/csv';
    return 'application/octet-stream';
  }
}
