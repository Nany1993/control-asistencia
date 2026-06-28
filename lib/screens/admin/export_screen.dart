import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../models/capacitacion.dart';
import '../../models/empresa.dart';
import '../../services/capacitacion_export_service.dart';
import '../../services/capacitacion_service.dart';
import '../../services/export_service.dart';
import '../../utils/persona_search.dart';

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
  DateTime? _capDesde;
  DateTime? _capHasta;
  bool _exporting = false;
  String? _lastFile;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final _capBusqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _capBusqueda.dispose();
    super.dispose();
  }

  List<Capacitacion> get _capacitacionesFiltradas {
    var list = _capacitaciones;

    if (_capDesde != null) {
      list = list.where((c) => !c.fechaDia.isBefore(_capDesde!)).toList();
    }
    if (_capHasta != null) {
      final hasta = DateTime(_capHasta!.year, _capHasta!.month, _capHasta!.day);
      list = list.where((c) => !c.fechaDia.isAfter(hasta)).toList();
    }

    final query = _capBusqueda.text.trim();
    if (query.isNotEmpty) {
      list = list.where((c) => _capacitacionMatches(c, query)).toList();
    }

    return list;
  }

  bool _capacitacionMatches(Capacitacion cap, String query) {
    final tokens = PersonaSearch.normalize(query)
        .split(' ')
        .where((t) => t.isNotEmpty);
    final haystack = PersonaSearch.normalize(
      '${cap.nombre} ${cap.temas} ${cap.expositor} '
      '${cap.empresaNombre ?? ''} ${_dateFormat.format(cap.fecha)} '
      '${cap.estadoLabel} ${cap.resultadoLabel ?? ''}',
    );

    for (final token in tokens) {
      if (!haystack.contains(token)) return false;
    }
    return true;
  }

  void _seleccionarCapacitacion(int? id) {
    setState(() => _capacitacionId = id);
  }

  void _limpiarFiltrosCapacitacion() {
    setState(() {
      _capDesde = null;
      _capHasta = null;
      _capBusqueda.clear();
      _capacitacionId = null;
    });
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

  Future<void> _pickDate({required bool desde, required bool capacitacion}) async {
    final cap = capacitacion;
    final initial = desde
        ? (cap ? (_capDesde ?? DateTime.now()) : (_desde ?? DateTime.now()))
        : (cap ? (_capHasta ?? DateTime.now()) : (_hasta ?? DateTime.now()));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (capacitacion) {
          if (desde) {
            _capDesde = DateTime(picked.year, picked.month, picked.day);
          } else {
            _capHasta = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          }
          if (_capacitacionId != null &&
              !_capacitacionesFiltradas.any((c) => c.id == _capacitacionId)) {
            _capacitacionId = null;
          }
        } else if (desde) {
          _desde = DateTime(picked.year, picked.month, picked.day);
        } else {
          _hasta = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  void _showResult({required bool share}) {
    final msg = share ? 'Reporte compartido' : 'Reporte guardado';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportAsistencia({bool pdf = false, bool share = false}) async {
    setState(() {
      _exporting = true;
      _lastFile = null;
    });

    try {
      final file = pdf
          ? await ExportService.instance.exportPdf(
              empresaId: _empresaId,
              desde: _desde,
              hasta: _hasta,
            )
          : await ExportService.instance.exportCsv(
              empresaId: _empresaId,
              desde: _desde,
              hasta: _hasta,
            );
      if (share) {
        await ExportService.instance.shareFile(
          file,
          text: pdf ? 'Reporte PDF de asistencia' : 'Reporte CSV de asistencia',
        );
      }
      if (mounted) {
        setState(() => _lastFile = file.path);
        _showResult(share: share);
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

  Future<bool> _asegurarCapacitacionCerradaParaPdf() async {
    final cap = await DbHelper.instance.getCapacitacion(_capacitacionId!);
    if (cap == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capacitacion no encontrada')),
        );
      }
      return false;
    }
    if (!cap.activa) return true;

    if (!mounted) return false;
    final cerrar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Capacitacion abierta'),
        content: Text(
          'La capacitacion "${cap.nombre}" aun esta abierta. '
          'Para exportar el informe PDF debe cerrarla primero.\n\n'
          '¿Desea cerrarla ahora? Se marcara como ejecutada o no ejecutada '
          'segun las asistencias registradas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar y exportar'),
          ),
        ],
      ),
    );
    if (cerrar != true) return false;

    await CapacitacionService.instance.cerrarCapacitacion(cap.id!);
    await _load();
    return true;
  }

  Future<void> _exportCapacitacion({
    required bool pdf,
    bool share = false,
  }) async {
    if (_capacitacionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccione una capacitacion')),
      );
      return;
    }

    if (pdf) {
      final puedeExportar = await _asegurarCapacitacionCerradaParaPdf();
      if (!puedeExportar) return;
    }

    setState(() {
      _exporting = true;
      _lastFile = null;
    });

    try {
      final file = pdf
          ? await CapacitacionExportService.instance.exportPdf(_capacitacionId!)
          : await CapacitacionExportService.instance.exportCsv(_capacitacionId!);

      if (share) {
        await CapacitacionExportService.instance.shareFile(
          file,
          text: pdf ? 'Informe de capacitacion' : 'Planilla de capacitacion',
        );
      }

      if (mounted) {
        setState(() => _lastFile = file.path);
        _showResult(share: share);
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
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.displayLabel)),
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
                    onPressed: () => _pickDate(desde: true, capacitacion: false),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hasta'),
                  subtitle: Text(_hasta?.toString().split(' ').first ?? 'Sin filtro'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(desde: false, capacitacion: false),
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
                FilledButton.icon(
                  onPressed: _exporting ? null : () => _exportAsistencia(pdf: true),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Generar PDF'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _exportAsistencia(pdf: true, share: true),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Generar y compartir PDF'),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desde'),
                  subtitle: Text(
                    _capDesde != null
                        ? _dateFormat.format(_capDesde!)
                        : 'Sin filtro',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(desde: true, capacitacion: true),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hasta'),
                  subtitle: Text(
                    _capHasta != null
                        ? _dateFormat.format(_capHasta!)
                        : 'Sin filtro',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _pickDate(desde: false, capacitacion: true),
                  ),
                ),
                if (_capDesde != null || _capHasta != null || _capBusqueda.text.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _limpiarFiltrosCapacitacion,
                      icon: const Icon(Icons.filter_alt_off),
                      label: const Text('Limpiar filtros'),
                    ),
                  ),
                const SizedBox(height: 8),
                PersonaSearchField(
                  controller: _capBusqueda,
                  hintText: 'Buscar por nombre, expositor, temas o empresa...',
                  onChanged: (_) {
                    setState(() {
                      if (_capacitacionId != null &&
                          !_capacitacionesFiltradas.any((c) => c.id == _capacitacionId)) {
                        _capacitacionId = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  '${_capacitacionesFiltradas.length} capacitacion(es)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (_capacitaciones.isEmpty)
                  const Text('No hay capacitaciones registradas')
                else if (_capacitacionesFiltradas.isEmpty)
                  const Text('Sin coincidencias con los filtros actuales')
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _capacitacionesFiltradas.length,
                      itemBuilder: (context, index) {
                        final cap = _capacitacionesFiltradas[index];
                        final selected = _capacitacionId == cap.id;
                        return Card(
                          color: selected ? Colors.blue.shade50 : null,
                          child: ListTile(
                            selected: selected,
                            title: Text(cap.nombre),
                            subtitle: Text(
                              '${_dateFormat.format(cap.fecha)} · ${cap.expositor}'
                              '${cap.empresaNombre != null ? ' · ${cap.empresaNombre}' : ''}'
                              ' · ${cap.estadoLabel}',
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_circle, color: Colors.blue)
                                : null,
                            onTap: () => _seleccionarCapacitacion(cap.id),
                          ),
                        );
                      },
                    ),
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
                OutlinedButton.icon(
                  onPressed: _exporting ? null : () => _exportCapacitacion(pdf: false),
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Generar CSV'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _exporting
                      ? null
                      : () => _exportCapacitacion(pdf: false, share: true),
                  icon: const Icon(Icons.share),
                  label: const Text('Generar CSV y compartir'),
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
