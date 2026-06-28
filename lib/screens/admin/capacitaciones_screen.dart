import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../database/referential_integrity_exception.dart';
import '../../models/capacitacion.dart';
import '../../models/empresa.dart';
import '../../services/capacitacion_service.dart';
import '../../services/photo_service.dart';

class CapacitacionesScreen extends StatefulWidget {
  const CapacitacionesScreen({super.key});

  @override
  State<CapacitacionesScreen> createState() => _CapacitacionesScreenState();
}

class _CapacitacionesScreenState extends State<CapacitacionesScreen> {
  List<Capacitacion> _capacitaciones = [];
  bool _loading = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await CapacitacionService.instance.cerrarCapacitacionesVencidas();
    final data = await DbHelper.instance.getCapacitaciones();
    if (mounted) {
      setState(() {
        _capacitaciones = data;
        _loading = false;
      });
    }
  }

  Future<void> _cerrar(Capacitacion cap) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar capacitacion'),
        content: Text(
          'Cerrar "${cap.nombre}"? Se definira como ejecutada o no ejecutada segun asistencia.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar')),
        ],
      ),
    );
    if (ok != true) return;
    await CapacitacionService.instance.cerrarCapacitacion(cap.id!);
    await _load();
  }

  Future<void> _delete(Capacitacion cap) async {
    final asistencias = await DbHelper.instance.countAsistenciaCapacitacion(cap.id!);
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar capacitacion'),
        content: Text(
          asistencias > 0
              ? 'No se puede eliminar "${cap.nombre}" porque tiene '
                  '$asistencias asistencia(s) registrada(s).'
              : 'Eliminar "${cap.nombre}"? Solo es posible si no tiene asistencias.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          if (asistencias == 0)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await DbHelper.instance.deleteCapacitacion(cap.id!);
      await _load();
    } on ReferentialIntegrityException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openForm([Capacitacion? cap]) async {
    if (cap != null && !cap.activa) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se puede editar una capacitacion cerrada.'),
        ),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CapacitacionFormDialog(capacitacion: cap),
    );
    if (saved == true) await _load();
  }

  Color _estadoColor(Capacitacion cap) {
    if (cap.activa) return Colors.blue;
    if (cap.resultado == ResultadoCapacitacion.ejecutada.value) {
      return Colors.green;
    }
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capacitaciones'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _capacitaciones.isEmpty
              ? const Center(child: Text('No hay capacitaciones registradas'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _capacitaciones.length,
                  itemBuilder: (context, index) {
                    final cap = _capacitaciones[index];
                    final estadoColor = _estadoColor(cap);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: estadoColor.withValues(alpha: 0.15),
                          child: Icon(Icons.school, color: estadoColor),
                        ),
                        title: Text(cap.nombre),
                        subtitle: Text(
                          [
                            _dateFormat.format(cap.fecha),
                            'Expositor: ${cap.expositor}',
                            cap.estadoLabel,
                            if (cap.resultadoLabel != null) cap.resultadoLabel!,
                            '${cap.totalAsistentes ?? 0} asistentes',
                            if (cap.cierreAutomatico) 'Cierre automatico',
                          ].join(' · '),
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') await _openForm(cap);
                            if (v == 'close' && cap.activa) await _cerrar(cap);
                            if (v == 'delete') await _delete(cap);
                          },
                          itemBuilder: (_) => [
                            if (cap.activa)
                              const PopupMenuItem(value: 'edit', child: Text('Editar')),
                            if (cap.activa)
                              const PopupMenuItem(value: 'close', child: Text('Cerrar')),
                            const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _CapacitacionFormDialog extends StatefulWidget {
  const _CapacitacionFormDialog({this.capacitacion});

  final Capacitacion? capacitacion;

  @override
  State<_CapacitacionFormDialog> createState() => _CapacitacionFormDialogState();
}

class _CapacitacionFormDialogState extends State<_CapacitacionFormDialog> {
  final _nombre = TextEditingController();
  final _temas = TextEditingController();
  final _expositor = TextEditingController();
  final _picker = ImagePicker();

  List<Empresa> _empresas = [];
  DateTime _fecha = DateTime.now();
  int? _empresaId;
  File? _fotoNueva;
  String? _fotoPathExistente;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cap = widget.capacitacion;
    if (cap != null) {
      _nombre.text = cap.nombre;
      _temas.text = cap.temas;
      _expositor.text = cap.expositor;
      _fecha = cap.fecha;
      _empresaId = cap.empresaId;
      _fotoPathExistente = cap.fotoGeneralPath;
    }
    _loadEmpresas();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _temas.dispose();
    _expositor.dispose();
    super.dispose();
  }

  Future<void> _loadEmpresas() async {
    final empresas = await DbHelper.instance.getEmpresas(soloActivas: true);
    if (mounted) setState(() => _empresas = empresas);
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _tomarFotoGeneral() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
    );
    if (image != null && mounted) {
      setState(() {
        _fotoNueva = File(image.path);
        _fotoPathExistente = null;
      });
    }
  }

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    final temas = _temas.text.trim();
    final expositor = _expositor.text.trim();
    if (nombre.isEmpty || temas.isEmpty || expositor.isEmpty) {
      setState(() => _error = 'Nombre, temas y expositor son obligatorios');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      var cap = Capacitacion(
        id: widget.capacitacion?.id,
        nombre: nombre,
        temas: temas,
        expositor: expositor,
        fecha: _fecha,
        empresaId: _empresaId,
        fotoGeneralPath: widget.capacitacion?.fotoGeneralPath,
        activa: widget.capacitacion?.activa ?? true,
        resultado: widget.capacitacion?.resultado,
        cerradaEn: widget.capacitacion?.cerradaEn,
        cierreAutomatico: widget.capacitacion?.cierreAutomatico ?? false,
        createdAt: widget.capacitacion?.createdAt ?? DateTime.now(),
      );

      if (widget.capacitacion == null) {
        final id = await DbHelper.instance.insertCapacitacion(cap);
        cap = cap.copyWith(id: id);
      } else {
        await DbHelper.instance.updateCapacitacion(cap);
      }

      if (_fotoNueva != null && cap.id != null) {
        final path = await PhotoService.instance.saveCapacitacionGeneralPhoto(
          _fotoNueva!,
          cap.id!,
        );
        await DbHelper.instance.updateCapacitacion(
          cap.copyWith(fotoGeneralPath: path),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fotoMostrar = _fotoNueva ??
        (_fotoPathExistente != null ? File(_fotoPathExistente!) : null);

    return AlertDialog(
      title: Text(widget.capacitacion == null ? 'Nueva capacitacion' : 'Editar capacitacion'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _temas,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Temas tratados *',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expositor,
              decoration: const InputDecoration(
                labelText: 'Expositor *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha *'),
              subtitle: Text(DateFormat('dd/MM/yyyy').format(_fecha)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _pickFecha,
              ),
            ),
            DropdownButtonFormField<int?>(
              initialValue: _empresaId,
              decoration: const InputDecoration(
                labelText: 'Empresa organizadora (opcional)',
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
            const Text('Foto general (opcional)'),
            if (fotoMostrar != null && fotoMostrar.existsSync()) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(fotoMostrar, height: 120, fit: BoxFit.cover),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _tomarFotoGeneral,
              icon: const Icon(Icons.photo_camera),
              label: Text(fotoMostrar == null ? 'Tomar foto general' : 'Cambiar foto'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
