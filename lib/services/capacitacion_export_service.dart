import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../database/db_helper.dart';
import '../models/capacitacion.dart';
import '../models/asistencia_capacitacion.dart';

class CapacitacionExportService {
  CapacitacionExportService._();
  static final CapacitacionExportService instance = CapacitacionExportService._();

  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _timeFormat = DateFormat('HH:mm:ss');
  final _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  Future<File> exportCsv(int capacitacionId) async {
    final cap = await DbHelper.instance.getCapacitacion(capacitacionId);
    if (cap == null) throw Exception('Capacitacion no encontrada');

    final asistentes =
        await DbHelper.instance.getAsistenciasCapacitacion(
      capacitacionId: capacitacionId,
    );

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(
      'Capacitacion,Temas,Expositor,Fecha sesion,Estado,Resultado,Empresa,Tipo persona,Nombre,Tipo doc,Numero doc,Hora registro,Ruta foto',
    );

    for (final a in asistentes) {
      buffer.writeln(_csvRow(cap, a));
    }

    if (asistentes.isEmpty) {
      buffer.writeln(_csvEmptyRow(cap));
    }

    return _writeExportFile(
      'capacitacion_${_safeName(cap.nombre)}_${_fileStamp.format(DateTime.now())}.csv',
      buffer.toString(),
    );
  }

  Future<File> exportPdf(int capacitacionId) async {
    final cap = await DbHelper.instance.getCapacitacion(capacitacionId);
    if (cap == null) throw Exception('Capacitacion no encontrada');

    final asistentes =
        await DbHelper.instance.getAsistenciasCapacitacion(
      capacitacionId: capacitacionId,
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        footer: pdfFooter,
        build: (context) => [
          pw.Text(
            'Informe de asistencia a capacitacion',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          _infoRow('Capacitacion', cap.nombre),
          _infoRow('Temas tratados', cap.temas),
          _infoRow('Expositor', cap.expositor),
          _infoRow('Fecha programada', _dateFormat.format(cap.fecha)),
          _infoRow('Estado', cap.estadoLabel),
          if (cap.resultadoLabel != null)
            _infoRow('Resultado', cap.resultadoLabel!),
          if (cap.empresaNombre != null)
            _infoRow('Empresa', cap.empresaNombre!),
          _infoRow('Total asistentes', '${asistentes.length}'),
          pw.SizedBox(height: 8),
          pw.Text(
            fuenteInformacion,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 16),
          if (cap.tieneFotoGeneral) ...[
            pw.Text(
              'Foto general de la capacitacion',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildImage(cap.fotoGeneralPath!, width: 280, height: 180),
            pw.SizedBox(height: 16),
          ],
          if (cap.resultado == ResultadoCapacitacion.noEjecutada.value) ...[
            pw.Text(
              'La capacitacion no registro asistencia y quedo como no ejecutada.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ] else if (asistentes.isEmpty) ...[
            pw.Text(
              'No hay asistentes registrados.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ] else ...[
            pw.Text(
              'Listado de asistentes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const [
                '#',
                'Nombre',
                'Documento',
                'Empresa',
                'Tipo',
                'Hora',
              ],
              data: [
                for (var i = 0; i < asistentes.length; i++)
                  [
                    '${i + 1}',
                    asistentes[i].empleadoNombre ?? '',
                    asistentes[i].documentoLabel,
                    asistentes[i].empresaNombre ?? '',
                    asistentes[i].tipoPersonaLabel,
                    _timeFormat.format(asistentes[i].fechaHora),
                  ],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ],
      ),
    );

    if (asistentes.isNotEmpty &&
        cap.resultado != ResultadoCapacitacion.noEjecutada.value) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          footer: pdfFooter,
          build: (context) => [
            pw.Text(
              'Evidencia fotografica individual',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            for (var i = 0; i < asistentes.length; i++) ...[
              pw.Text(
                '${i + 1}. ${asistentes[i].empleadoNombre ?? ''} · '
                '${asistentes[i].documentoLabel} · '
                '${_timeFormat.format(asistentes[i].fechaHora)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              _buildImage(asistentes[i].fotoPath, width: 120, height: 120),
              pw.SizedBox(height: 16),
            ],
          ],
        ),
      );
    }

    final bytes = await pdf.save();
    final fileName =
        'Informe_${_safeName(cap.nombre)}_${_fileStamp.format(DateTime.now())}.pdf';
    final dir = await _exportsDir();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildImage(String path, {required double width, required double height}) {
    final file = File(path);
    if (!file.existsSync()) {
      return pw.Text('Foto no disponible');
    }
    final bytes = file.readAsBytesSync();
    final image = pw.MemoryImage(bytes);
    return pw.Image(image, width: width, height: height, fit: pw.BoxFit.cover);
  }

  String _csvRow(Capacitacion cap, AsistenciaCapacitacion a) {
    return [
      _escape(cap.nombre),
      _escape(cap.temas),
      _escape(cap.expositor),
      _dateFormat.format(cap.fecha),
      cap.estadoLabel,
      _escape(cap.resultadoLabel ?? ''),
      _escape(a.empresaNombre ?? ''),
      a.tipoPersonaLabel,
      _escape(a.empleadoNombre ?? ''),
      _escape(a.empleadoTipoDocumento ?? ''),
      _escape(a.empleadoNumeroDocumento ?? ''),
      _timeFormat.format(a.fechaHora),
      _escape(a.fotoPath),
    ].join(',');
  }

  String _csvEmptyRow(Capacitacion cap) {
    return [
      _escape(cap.nombre),
      _escape(cap.temas),
      _escape(cap.expositor),
      _dateFormat.format(cap.fecha),
      cap.estadoLabel,
      _escape(cap.resultadoLabel ?? ''),
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ].join(',');
  }

  String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _safeName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    if (cleaned.isEmpty) return 'capacitacion';
    return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
  }

  Future<Directory> _exportsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory(p.join(dir.path, 'exportes'));
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    return exportsDir;
  }

  Future<File> _writeExportFile(String name, String content) async {
    final dir = await _exportsDir();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(content);
    return file;
  }

  Future<void> shareFile(File file, {String? text}) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: text ?? 'Informe de capacitacion',
    );
  }
}
