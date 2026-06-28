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
import '../utils/texto_display.dart';

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
      'CAPACITACION,TEMAS,EXPOSITOR,FECHA SESION,ESTADO,RESULTADO,EMPRESA,'
      'TIPO PERSONA,NOMBRE,CARGO,TIPO DOC,NUMERO DOC,HORA REGISTRO,RUTA FOTO',
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
    final fuenteInformacion = TextoDisplay.mayus(
      'Fuente de la informacion: exportado el $exportadoEn desde la app Control Asistencia',
    );

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
            'INFORME DE ASISTENCIA A CAPACITACION',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          _infoRow('CAPACITACION', cap.nombre),
          _infoRow('TEMAS TRATADOS', cap.temas),
          _infoRow('EXPOSITOR', cap.expositor),
          _infoRow('FECHA PROGRAMADA', _dateFormat.format(cap.fecha)),
          _infoRow('ESTADO', cap.estadoLabel),
          if (cap.resultadoLabel != null)
            _infoRow('RESULTADO', cap.resultadoLabel!),
          if (cap.empresaNombre != null)
            _infoRow('EMPRESA', cap.empresaNombre!),
          _infoRow('TOTAL ASISTENTES', '${asistentes.length}'),
          pw.SizedBox(height: 8),
          pw.Text(
            fuenteInformacion,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.SizedBox(height: 16),
          if (cap.tieneFotoGeneral) ...[
            pw.Text(
              'FOTO GENERAL DE LA CAPACITACION',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildImage(cap.fotoGeneralPath!, width: 280, height: 180),
            pw.SizedBox(height: 16),
          ],
          if (cap.resultado == ResultadoCapacitacion.noEjecutada.value) ...[
            pw.Text(
              'LA CAPACITACION NO REGISTRO ASISTENCIA Y QUEDO COMO NO EJECUTADA.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ] else if (asistentes.isEmpty) ...[
            pw.Text(
              'NO HAY ASISTENTES REGISTRADOS.',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ] else ...[
            pw.Text(
              'LISTADO DE ASISTENTES',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const [
                '#',
                'NOMBRE',
                'CARGO',
                'DOCUMENTO',
                'EMPRESA',
                'TIPO',
                'HORA',
              ],
              data: [
                for (var i = 0; i < asistentes.length; i++)
                  [
                    '${i + 1}',
                    _cell(asistentes[i].empleadoNombre ?? ''),
                    _cell(asistentes[i].empleadoCargo ?? ''),
                    _cell(asistentes[i].documentoLabel),
                    _cell(asistentes[i].empresaNombre ?? ''),
                    _cell(asistentes[i].tipoPersonaLabel),
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
              'EVIDENCIA FOTOGRAFICA INDIVIDUAL',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            for (var i = 0; i < asistentes.length; i++) ...[
              pw.Text(
                '${i + 1}. ${_cell(asistentes[i].empleadoNombre ?? '')}'
                '${_cargoPdfSuffix(asistentes[i].empleadoCargo)}'
                ' · ${_cell(asistentes[i].documentoLabel)}'
                ' · ${_timeFormat.format(asistentes[i].fechaHora)}',
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
              text: '${TextoDisplay.mayus(label)}: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: _cell(value)),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildImage(String path, {required double width, required double height}) {
    final file = File(path);
    if (!file.existsSync()) {
      return pw.Text('FOTO NO DISPONIBLE');
    }
    final bytes = file.readAsBytesSync();
    final image = pw.MemoryImage(bytes);
    return pw.Image(image, width: width, height: height, fit: pw.BoxFit.cover);
  }

  String _cargoPdfSuffix(String? cargo) {
    if (cargo == null || cargo.trim().isEmpty) return '';
    return ' · ${_cell(cargo)}';
  }

  String _cell(String value) => TextoDisplay.mayus(value);

  String _csvRow(Capacitacion cap, AsistenciaCapacitacion a) {
    return [
      _escape(_cell(cap.nombre)),
      _escape(_cell(cap.temas)),
      _escape(_cell(cap.expositor)),
      _dateFormat.format(cap.fecha),
      _cell(cap.estadoLabel),
      _escape(_cell(cap.resultadoLabel ?? '')),
      _escape(_cell(a.empresaNombre ?? '')),
      _cell(a.tipoPersonaLabel),
      _escape(_cell(a.empleadoNombre ?? '')),
      _escape(_cell(a.empleadoCargo ?? '')),
      _escape(_cell(a.empleadoTipoDocumento ?? '')),
      _escape(_cell(a.empleadoNumeroDocumento ?? '')),
      _timeFormat.format(a.fechaHora),
      _escape(a.fotoPath),
    ].join(',');
  }

  String _csvEmptyRow(Capacitacion cap) {
    return [
      _escape(_cell(cap.nombre)),
      _escape(_cell(cap.temas)),
      _escape(_cell(cap.expositor)),
      _dateFormat.format(cap.fecha),
      _cell(cap.estadoLabel),
      _escape(_cell(cap.resultadoLabel ?? '')),
      '',
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
      text: text ?? 'INFORME DE CAPACITACION',
    );
  }
}
