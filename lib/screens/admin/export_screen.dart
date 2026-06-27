import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../models/capacitacion.dart';
import '../../models/empresa.dart';
import '../../services/capacitacion_export_service.dart';
import '../../services/email_service.dart';
import '../../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  List<Empresa> _empresas = [];
  List<Capacitacion> _capacitaciones = [];
  int? _empresaId;
  int? _capacitacionId;
  DateTime? _desde;
  DateTime? _hasta;
  bool _exporting = false;
  String? _lastFile;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final empresas = await DbHelper.instance.getEmpresas();
    final caps = await DbHelper.instance.getCapacitaciones();
    if (mounted) {
      setState(() {
        _empresas = empresas;
        _capacitaciones = caps;
      });
    }
  }

  Future<void> _pickDate({required bool desde}) async {
    final initial = desde ? (_desde ?? DateTime.now()) : (_hasta ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (desde) {
          _desde = DateTime(picked.year, picked.month, picked.day);
        } else {
          _hasta = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  void _showResult({required bool share, required bool email}) {
    final msg = email
        ? 'Gmail abierto con el reporte adjunto'
        : share
            ? 'Reporte compartido'
            : 'Reporte guardado';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportAsistencia({bool share = false, bool email = false}) async {
    setState(() {
      _exporting = true;
      _lastFile = null;
    });

    try {
      final file = await ExportService.instance.exportCsv(
        empresaId: _empresaId,
        desde: _desde,
        hasta: _hasta,
      );
      if (share) {
        await ExportService.instance.shareFile(file);
      } else if (email) {
        await EmailService.instance.sendViaGmail(
          file: file,
          subject: 'Reporte de asistencia - ${_dateFormat.format(DateTime.now())}',
          body: 'Adjunto reporte de asistencia generado desde Control Asistencia.',
        );
      }
      if (mounted) {
        setState(() => _lastFile = file.path);
        _showResult(share: share, email: email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportCapacitacion({
    required bool pdf,
    bool share = false,
    bool email = false,
  }) async {
    if (_capacitacionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione una capacitacion')),
      );
      return;
    }

    setState(() {
      _exporting = true;
      _lastFile = null;
    });

    try {
      final cap = _capacitaciones.firstWhere((c) => c.id == _capacitacionId);
      final file = pdf
          ? await CapacitacionExportService.instance.exportPdf(_capacitacionId!)
          : await CapacitacionExportService.instance.exportCsv(_capacitacionId!);

      if (share) {
        await CapacitacionExportService.instance.shareFile(
          file,
          text: pdf ? 'Informe de capacitacion' : 'Planilla de capacitacion',
        );
      } else if (email) {
        final tipo = pdf ? 'Informe PDF' : 'Planilla CSV';
        await EmailService.instance.sendViaGmail(
          file: file,
          subject: '$tipo capacitacion - ${cap.nombre}',
          body: 'Adjunto $tipo de la capacitacion "${cap.nombre}" '
              'generado desde Control Asistencia.',
        );
      }

      if (mounted) {
        setState(() => _lastFile = file.path);
        _showResult(share: share, email: email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _gmailButton({required VoidCallback onPressed}) {
    return OutlinedButton.icon(
      onPressed: _exporting ? null : onPressed,
      icon: const Icon(Icons.email_outlined),
      label: const Text('Enviar por Gmail'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exportar'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Asistencia laboral'),
              Tab(text: 'Capacitaciones'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: _empresaId,
                  decoration: const InputDecoration(
                    labelText: 'Empresa',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                    ..._empresas.map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _empresaId = v),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desde'),
                  subtitle: Text(_desde?.toString().split(' ').first ?? 'Sin filtro'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(desde: true),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hasta'),
                  subtitle: Text(_hasta?.toString().split(' ').first ?? 'Sin filtro'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(desde: false),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _exporting ? null : () => _exportAsistencia(),
                  icon: const Icon(Icons.save),
                  label: const Text('Generar CSV'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _exportAsistencia(share: true),
                  icon: const Icon(Icons.share),
                  label: const Text('Generar y compartir CSV'),
                ),
                const SizedBox(height: 12),
                _gmailButton(onPressed: () => _exportAsistencia(email: true)),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int?>(
                  initialValue: _capacitacionId,
                  decoration: const InputDecoration(
                    labelText: 'Capacitacion',
                    border: OutlineInputBorder(),
                  ),
                  items: _capacitaciones
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _capacitacionId = v),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _exporting ? null : () => _exportCapacitacion(pdf: true),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generar informe PDF'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exporting
                      ? null
                      : () => _exportCapacitacion(pdf: true, share: true),
                  icon: const Icon(Icons.share),
                  label: const Text('Generar PDF y compartir'),
                ),
                const SizedBox(height: 12),
                _gmailButton(
                  onPressed: () => _exportCapacitacion(pdf: true, email: true),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _exportCapacitacion(pdf: false),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Generar CSV'),
                ),
                const SizedBox(height: 12),
                _gmailButton(
                  onPressed: () => _exportCapacitacion(pdf: false, email: true),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _lastFile == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Ultimo archivo:\n$_lastFile',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
      ),
    );
  }
}
