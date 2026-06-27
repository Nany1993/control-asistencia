import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/registro.dart';

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _timeFormat = DateFormat('HH:mm:ss');
  final _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  Future<File> exportCsv({
    int? empresaId,
    int? empleadoId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final registros = await DbHelper.instance.getRegistros(
      empresaId: empresaId,
      empleadoId: empleadoId,
      desde: desde,
      hasta: hasta,
    );

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(
      'Empresa,Tipo persona,Empleado,Turno,Tipo documento,Numero documento,Fecha,Hora,Tipo marcacion,Motivo salida,Radicado,Observacion,Ruta foto',
    );

    for (final registro in registros) {
      buffer.writeln(_row(registro));
    }

    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exportes'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }

    final file = File(
      p.join(exportsDir.path, 'asistencia_${_fileStamp.format(DateTime.now())}.csv'),
    );
    await file.writeAsString(buffer.toString());
    return file;
  }

  String _row(Registro registro) {
    final cells = [
      _escape(registro.empresaNombre ?? ''),
      registro.tipoPersonaLabel,
      _escape(registro.empleadoNombre ?? ''),
      _escape(registro.turnoNombre ?? ''),
      _escape(registro.empleadoTipoDocumento ?? ''),
      _escape(registro.empleadoNumeroDocumento ?? ''),
      _dateFormat.format(registro.fechaHora),
      _timeFormat.format(registro.fechaHora),
      registro.tipo.label,
      _escape(registro.motivoSalidaLabel ?? ''),
      _escape(registro.radicado ?? ''),
      _escape(registro.observacion ?? ''),
      _escape(registro.fotoPath),
    ];
    return cells.join(',');
  }

  String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> shareFile(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Reporte de asistencia',
    );
  }
}
