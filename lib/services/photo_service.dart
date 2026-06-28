import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

  static const sistemaSinFoto = 'sistema://sin-foto';

  static bool esFotoSistema(String path) =>
      path == sistemaSinFoto || path.startsWith('sistema://');

  Future<String> savePhoto(File source, int empresaId, int empleadoId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, 'fotos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'e${empresaId}_emp${empleadoId}_$timestamp.jpg';
    final destination = File(p.join(photosDir.path, fileName));
    await source.copy(destination.path);
    return destination.path;
  }

  Future<String> saveCapacitacionGeneralPhoto(File source, int capacitacionId) async {
    return _saveInSubdir(source, 'fotos_capacitaciones', 'cap${capacitacionId}_general');
  }

  Future<String> saveCapacitacionAsistenciaPhoto(
    File source,
    int capacitacionId,
    int empleadoId,
  ) async {
    return _saveInSubdir(
      source,
      'fotos_capacitaciones',
      'cap${capacitacionId}_emp$empleadoId',
    );
  }

  Future<String> _saveInSubdir(File source, String subdir, String prefix) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(appDir.path, subdir));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${prefix}_$timestamp.jpg';
    final destination = File(p.join(photosDir.path, fileName));
    await source.copy(destination.path);
    return destination.path;
  }
}
