import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PhotoService {
  PhotoService._();
  static final PhotoService instance = PhotoService._();

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
}
