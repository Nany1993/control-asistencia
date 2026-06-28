import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/backup_restore_exception.dart';
import '../database/db_helper.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const _dbVersion = 15;
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

  Future<void> restoreBackup(File zipFile) async {
    if (!await zipFile.exists()) {
      throw BackupRestoreException('El archivo de respaldo no existe.');
    }

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.isEmpty) {
      throw BackupRestoreException('El archivo ZIP esta vacio.');
    }

    ArchiveFile? manifestFile;
    ArchiveFile? dbArchiveFile;
    for (final file in archive) {
      if (file.name == 'manifest.json') manifestFile = file;
      if (file.name == 'database/control_asistencia.db') dbArchiveFile = file;
    }

    if (manifestFile == null) {
      throw BackupRestoreException('Respaldo invalido: falta manifest.json.');
    }

    final manifest = jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    if (manifest['app'] != 'control_asistencia') {
      throw BackupRestoreException('El archivo no es un respaldo de Control Asistencia.');
    }
    final version = manifest['db_version'];
    if (version is! int || version > _dbVersion) {
      throw BackupRestoreException(
        'Respaldo incompatible (version $version). '
        'Actualice la app e intente de nuevo.',
      );
    }
    if (dbArchiveFile == null) {
      throw BackupRestoreException('Respaldo invalido: falta la base de datos.');
    }

    await DbHelper.instance.closeForBackup();

    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = await DbHelper.databaseFilePath();
    await File(dbPath).writeAsBytes(dbArchiveFile.content, flush: true);

    await _restoreArchiveDirectory(archive, 'fotos', p.join(appDir.path, 'fotos'));
    await _restoreArchiveDirectory(
      archive,
      'fotos_capacitaciones',
      p.join(appDir.path, 'fotos_capacitaciones'),
    );
    await _restoreArchiveDirectory(archive, 'exportes', p.join(appDir.path, 'exportes'));
  }

  Future<void> _restoreArchiveDirectory(
    Archive archive,
    String prefix,
    String targetDirPath,
  ) async {
    final targetDir = Directory(targetDirPath);
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }
    await targetDir.create(recursive: true);

    final normalizedPrefix = '$prefix/';
    for (final file in archive) {
      if (!file.isFile || !file.name.startsWith(normalizedPrefix)) continue;
      final relative = file.name.substring(normalizedPrefix.length);
      if (relative.isEmpty) continue;

      final outPath = p.join(targetDir.path, relative);
      final outFile = File(outPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(file.content, flush: true);
    }
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
