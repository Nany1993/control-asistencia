import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/registro.dart';

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _timeFormat = DateFormat('HH:mm:ss');
  final _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  Future<List<Registro>> _fetchRegistros({
    int? empresaId,
    int? empleadoId,
    DateTime? desde,
    DateTime? hasta,
  }) {
    return DbHelper.instance.getRegistros(
      empresaId: empresaId,
      empleadoId: empleadoId,
      desde: desde,
      hasta: hasta,
    );
  }

  Future<File> exportCsv({
    int? empresaId,
    int? empleadoId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final registros = await _fetchRegistros(
      empresaId: empresaId,
      empleadoId: empleadoId,
      desde: desde,
      hasta: hasta,
    );

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(
      'Empresa,Tipo persona,Empleado,Cargo,Turno,Tipo documento,Numero documento,Fecha,Hora,Tipo marcacion,Motivo salida,Radicado,Observacion,Ruta foto',
    );

    for (final registro in registros) {
      buffer.writeln(_row(registro));
    }

    return _writeFile(
      'asistencia_${_fileStamp.format(DateTime.now())}.csv',
      buffer.toString(),
    );
  }

  Future<File> exportPdf({
    int? empresaId,
    int? empleadoId,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final registros = await _fetchRegistros(
      empresaId: empresaId,
      empleadoId: empleadoId,
      desde: desde,
      hasta: hasta,
    );

    final pdf = pw.Document();
    final generado = DateTime.now();
    final exportadoEn =
        '${_dateFormat.format(generado)} ${_timeFormat.format(generado)}';
    final fuenteInformacion =
        'Fuente de la informacion: exportado el $exportadoEn desde la app Control Asistencia';

    pw.Widget pdfFooter(pw.Context context) {
      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Text(
          fuenteInformacion,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        footer: pdfFooter,
        build: (context) => [
          pw.Text(
            'Reporte de asistencia laboral',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Total registros: ${registros.length}'),
          pw.Text(fuenteInformacion, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 16),
          if (registros.isEmpty)
            pw.Text('No hay registros para los filtros seleccionados.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Empresa',
                'Tipo',
                'Nombre',
                'Cargo',
                'Documento',
                'Turno',
                'Fecha',
                'Hora',
                'Marcacion',
                'Observacion',
              ],
              data: [
                for (final r in registros)
                  [
                    r.empresaNombre ?? '',
                    r.tipoPersonaLabel,
                    r.empleadoNombre ?? '',
                    r.empleadoCargo ?? '',
                    '${r.empleadoTipoDocumento ?? ''} ${r.empleadoNumeroDocumento ?? ''}'.trim(),
                    r.turnoNombre ?? '',
                    _dateFormat.format(r.fechaHora),
                    _timeFormat.format(r.fechaHora),
                    r.tipo.label,
                    [
                      if (r.motivoSalidaLabel != null) r.motivoSalidaLabel!,
                      if (r.radicado != null && r.radicado!.isNotEmpty)
                        'Rad: ${r.radicado}',
                      if (r.observacion != null && r.observacion!.isNotEmpty)
                        r.observacion!,
                    ].join(' · '),
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellStyle: const pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final dir = await _exportsDir();
    final file = File(
      p.join(dir.path, 'asistencia_${_fileStamp.format(DateTime.now())}.pdf'),
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  String _row(Registro registro) {
    final cells = [
      _escape(registro.empresaNombre ?? ''),
      registro.tipoPersonaLabel,
      _escape(registro.empleadoNombre ?? ''),
      _escape(registro.empleadoCargo ?? ''),
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

  Future<Directory> _exportsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exportes'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  Future<File> _writeFile(String name, String content) async {
    final dir = await _exportsDir();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(content);
    return file;
  }

  Future<void> shareFile(File file, {String? text}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text ?? 'Reporte de asistencia',
    );
  }
}
