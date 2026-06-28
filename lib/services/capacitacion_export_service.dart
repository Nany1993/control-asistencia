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
  final _timeFormat = DateFormat('HH:mm');
  final _fileStamp = DateFormat('yyyyMMdd_HHmmss');

  static final _azul = PdfColor.fromInt(0xFF1565C0);
  static final _azulClaro = PdfColor.fromInt(0xFFE3F2FD);
  static final _grisTexto = PdfColor.fromInt(0xFF424242);
  static final _grisSuave = PdfColor.fromInt(0xFF757575);

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
      'CAPACITACION,TEMAS,DESCRIPCION,EXPOSITOR,FECHA SESION,ESTADO,RESULTADO,EMPRESA,'
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

    pw.Widget pdfFooter(pw.Context context) {
      return pw.Container(
        padding: const pw.EdgeInsets.only(top: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              _pdfText('Control Asistencia · $exportadoEn'),
              style: pw.TextStyle(fontSize: 8, color: _grisSuave),
            ),
            pw.Text(
              'Pagina ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _grisSuave),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 48),
        footer: pdfFooter,
        build: (context) => [
          _pdfHeader(cap.nombre),
          pw.SizedBox(height: 20),
          _infoCard(cap, asistentes.length),
          if (cap.tieneFotoGeneral) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Foto General'),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 8,
                  verticalRadius: 8,
                  child: _buildImage(cap.fotoGeneralPath!, width: 320, height: 200),
                ),
              ),
            ),
          ],
          if (cap.tieneDescripcion) ...[
            pw.SizedBox(height: 20),
            _sectionTitle('Descripcion'),
            pw.SizedBox(height: 8),
            _descriptionBox(cap.descripcion),
          ],
          pw.SizedBox(height: 24),
          if (cap.resultado == ResultadoCapacitacion.noEjecutada.value)
            _noticeBox(
              'La capacitacion no registro asistencia y quedo como no ejecutada.',
            )
          else if (asistentes.isEmpty)
            _noticeBox('No hay asistentes registrados.')
          else ...[
            _sectionTitle('Listado De Asistentes'),
            pw.SizedBox(height: 10),
            _asistentesTable(asistentes),
          ],
        ],
      ),
    );

    if (asistentes.isNotEmpty &&
        cap.resultado != ResultadoCapacitacion.noEjecutada.value) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 48),
          footer: pdfFooter,
          build: (context) => [
            _sectionTitle('Evidencia Fotografica Individual'),
            pw.SizedBox(height: 14),
            ...asistentes.asMap().entries.map((entry) {
              final i = entry.key;
              final a = entry.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 16),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: i.isEven ? PdfColors.grey100 : PdfColors.white,
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 28,
                      height: 28,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: _azul,
                        borderRadius: pw.BorderRadius.circular(14),
                      ),
                      child: pw.Text(
                        '${i + 1}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _pdfText(a.empleadoNombre ?? ''),
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: _grisTexto,
                            ),
                          ),
                          if (a.empleadoCargo != null &&
                              a.empleadoCargo!.trim().isNotEmpty)
                            pw.Text(
                              _pdfText(a.empleadoCargo!),
                              style: pw.TextStyle(fontSize: 10, color: _grisSuave),
                            ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '${_pdfText(a.documentoLabel)} · '
                            '${_pdfText(a.empresaNombre ?? '')} · '
                            '${_pdfText(a.tipoPersonaLabel)} · '
                            '${_timeFormat.format(a.fechaHora)}',
                            style: pw.TextStyle(fontSize: 9, color: _grisSuave),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Container(
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 6,
                        verticalRadius: 6,
                        child: _buildImage(a.fotoPath, width: 88, height: 88),
                      ),
                    ),
                  ],
                ),
              );
            }),
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

  pw.Widget _pdfHeader(String nombreCapacitacion) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: pw.BoxDecoration(
        color: _azul,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informe De Asistencia A Capacitacion',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _pdfText(nombreCapacitacion),
            style: const pw.TextStyle(
              fontSize: 13,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
        ),
      ),
      child: pw.Text(
        _pdfText(title),
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: _azul,
        ),
      ),
    );
  }

  pw.Widget _infoCard(Capacitacion cap, int totalAsistentes) {
    final filas = <(String, String)>[
      ('Temas Generales', cap.temas),
      ('Expositor', cap.expositor),
      ('Fecha Programada', _dateFormat.format(cap.fecha)),
      ('Estado', cap.estadoLabel),
      if (cap.resultadoLabel != null) ('Resultado', cap.resultadoLabel!),
      if (cap.empresaNombre != null) ('Empresa', cap.empresaNombre!),
      ('Total Asistentes', '$totalAsistentes'),
    ];

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _azulClaro,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColor.fromInt(0xFF90CAF9)),
      ),
      child: pw.Wrap(
        spacing: 24,
        runSpacing: 10,
        children: [
          for (final (label, value) in filas)
            pw.SizedBox(
              width: 220,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    _pdfText(label),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _azul,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    _pdfText(value),
                    style: pw.TextStyle(fontSize: 11, color: _grisTexto),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _descriptionBox(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text(
        _pdfText(text),
        style: pw.TextStyle(fontSize: 10.5, color: _grisTexto, lineSpacing: 1.35),
      ),
    );
  }

  pw.Widget _noticeBox(String message) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.amber200),
      ),
      child: pw.Text(
        _pdfText(message),
        style: pw.TextStyle(fontSize: 11, color: _grisTexto),
      ),
    );
  }

  pw.Widget _asistentesTable(List<AsistenciaCapacitacion> asistentes) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(28),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
        5: const pw.FixedColumnWidth(52),
        6: const pw.FixedColumnWidth(44),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _azul),
          children: [
            for (final h in ['#', 'Nombre', 'Cargo', 'Documento', 'Empresa', 'Tipo', 'Hora'])
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: pw.Text(
                  _pdfText(h),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
          ],
        ),
        for (var i = 0; i < asistentes.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : PdfColors.grey100,
            ),
            children: [
              _tableCell('${i + 1}', bold: false),
              _tableCell(asistentes[i].empleadoNombre ?? ''),
              _tableCell(asistentes[i].empleadoCargo ?? ''),
              _tableCell(asistentes[i].documentoLabel),
              _tableCell(asistentes[i].empresaNombre ?? ''),
              _tableCell(asistentes[i].tipoPersonaLabel),
              _tableCell(_timeFormat.format(asistentes[i].fechaHora)),
            ],
          ),
      ],
    );
  }

  pw.Widget _tableCell(String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      child: pw.Text(
        _pdfText(value),
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _grisTexto,
        ),
      ),
    );
  }

  pw.Widget _buildImage(String path, {required double width, required double height}) {
    final file = File(path);
    if (!file.existsSync()) {
      return pw.Container(
        width: width,
        height: height,
        alignment: pw.Alignment.center,
        color: PdfColors.grey200,
        child: pw.Text(
          _pdfText('Foto no disponible'),
          style: pw.TextStyle(fontSize: 9, color: _grisSuave),
        ),
      );
    }
    final bytes = file.readAsBytesSync();
    final image = pw.MemoryImage(bytes);
    return pw.Image(image, width: width, height: height, fit: pw.BoxFit.cover);
  }

  String _pdfText(String value) => TextoDisplay.tituloPalabras(value);

  String _csvCell(String value) => TextoDisplay.mayus(value);

  String _csvRow(Capacitacion cap, AsistenciaCapacitacion a) {
    return [
      _escape(_csvCell(cap.nombre)),
      _escape(_csvCell(cap.temas)),
      _escape(_csvCell(cap.descripcion)),
      _escape(_csvCell(cap.expositor)),
      _dateFormat.format(cap.fecha),
      _csvCell(cap.estadoLabel),
      _escape(_csvCell(cap.resultadoLabel ?? '')),
      _escape(_csvCell(a.empresaNombre ?? '')),
      _csvCell(a.tipoPersonaLabel),
      _escape(_csvCell(a.empleadoNombre ?? '')),
      _escape(_csvCell(a.empleadoCargo ?? '')),
      _escape(_csvCell(a.empleadoTipoDocumento ?? '')),
      _escape(_csvCell(a.empleadoNumeroDocumento ?? '')),
      _timeFormat.format(a.fechaHora),
      _escape(a.fotoPath),
    ].join(',');
  }

  String _csvEmptyRow(Capacitacion cap) {
    return [
      _escape(_csvCell(cap.nombre)),
      _escape(_csvCell(cap.temas)),
      _escape(_csvCell(cap.descripcion)),
      _escape(_csvCell(cap.expositor)),
      _dateFormat.format(cap.fecha),
      _csvCell(cap.estadoLabel),
      _escape(_csvCell(cap.resultadoLabel ?? '')),
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
      text: text ?? 'Informe de capacitacion',
    );
  }
}
