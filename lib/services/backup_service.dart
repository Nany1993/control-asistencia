import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _dbVersion = 10;
  final _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  Future<File> createBackup() async {
    await DbHelper.instance.closeForBackup();

    final appDir = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(appDir.path, 'respaldos'));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }

    final zipName = 'control_asistencia_respaldo_${_fileStamp.format(DateTime.now())}.zip';
    final zipPath = p.join(backupsDir.path, zipName);

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      final manifest = {
        'app': 'control_asistencia',
        'created_at': DateTime.now().toIso8601String(),
        'db_version': _dbVersion,
      };
      encoder.addArchiveFile(
        ArchiveFile(
          'manifest.json',
          utf8.encode(jsonEncode(manifest)).length,
          utf8.encode(jsonEncode(manifest)),
        ),
      );

      final dbPath = await DbHelper.databaseFilePath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        encoder.addFile(dbFile, 'database/control_asistencia.db');
      }

      await _addDirectory(
        encoder,
        Directory(p.join(appDir.path, 'fotos')),
        'fotos',
      );
      await _addDirectory(
        encoder,
        Directory(p.join(appDir.path, 'fotos_capacitaciones')),
        'fotos_capacitaciones',
      );
      await _addDirectory(
        encoder,
        Directory(p.join(appDir.path, 'exportes')),
        'exportes',
      );
    } finally {
      encoder.close();
    }

    return File(zipPath);
  }

  Future<void> _addDirectory(
    ZipFileEncoder encoder,
    Directory dir,
    String archivePrefix,
  ) async {
    if (!await dir.exists()) return;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: dir.path);
      final archivePath = p.join(archivePrefix, relative).replaceAll('\\', '/');
      encoder.addFile(entity, archivePath);
    }
  }

  Future<void> shareBackup(File file) async {
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/zip')],
      text: 'Respaldo Control Asistencia',
      subject: 'Respaldo Control Asistencia',
    );
  }
}
