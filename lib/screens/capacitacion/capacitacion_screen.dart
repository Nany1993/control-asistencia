import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sqflite/sqflite.dart';

import '../../database/db_helper.dart';
import '../../models/capacitacion.dart';
import '../../models/empleado.dart';
import '../../models/asistencia_capacitacion.dart';
import '../../services/capacitacion_service.dart';
import '../../services/photo_service.dart';
import '../../utils/persona_search.dart';
import '../../widgets/info_text.dart';

class CapacitacionScreen extends StatefulWidget {
  const CapacitacionScreen({super.key});

  @override
  State<CapacitacionScreen> createState() => _CapacitacionScreenState();
}

class _CapacitacionScreenState extends State<CapacitacionScreen> {
  final _picker = ImagePicker();
  final _busqueda = TextEditingController();

  List<Capacitacion> _capacitaciones = [];
  List<Empleado> _personas = [];
  Set<int> _asistieronIds = {};
  Capacitacion? _capacitacion;
  Empleado? _empleado;
  File? _foto;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await CapacitacionService.instance.cerrarCapacitacionesVencidas();
    final caps = await DbHelper.instance.getCapacitaciones(
      soloAbiertas: true,
      soloHoy: true,
    );
    if (mounted) {
      setState(() {
        _capacitaciones = caps;
        _loading = false;
        if (_capacitacion != null &&
            !caps.any((c) => c.id == _capacitacion!.id)) {
          _resetSeleccion();
        }
      });
    }
  }

  void _resetSeleccion() {
    _capacitacion = null;
    _empleado = null;
    _personas = [];
    _asistieronIds = {};
    _foto = null;
    _busqueda.clear();
  }

  Future<void> _onCapacitacionSelected(Capacitacion? cap) async {
    setState(() {
      _capacitacion = cap;
      _empleado = null;
      _foto = null;
      _busqueda.clear();
      _personas = [];
      _asistieronIds = {};
    });

    if (cap == null) return;

    final personas = await DbHelper.instance.getEmpleados(
      soloActivos: true,
      soloEmpresasActivas: true,
    );
    final asistieron = await DbHelper.instance.getEmpleadoIdsAsistenciaCapacitacion(
      cap.id!,
    );
    if (mounted) {
      setState(() {
        _personas = personas;
        _asistieronIds = asistieron;
      });
    }
  }

  static const _maxResultadosBusqueda = 10;

  List<Empleado> get _coincidenciasBusqueda {
    if (_busqueda.text.trim().isEmpty) return [];
    return _personas.where((p) {
      return PersonaSearch.matches(
        nombre: p.nombre,
        tipoDocumento: p.tipoDocumento,
        numeroDocumento: p.numeroDocumento,
        cargo: p.cargo,
        empresaNombre: p.empresaNombre ?? '',
        query: _busqueda.text,
      );
    }).toList();
  }

  List<Empleado> get _personasFiltradas =>
      _coincidenciasBusqueda.take(_maxResultadosBusqueda).toList();

  bool get _hayMasCoincidencias =>
      _coincidenciasBusqueda.length > _maxResultadosBusqueda;

  void _seleccionarPersona(Empleado persona) {
    if (_asistieronIds.contains(persona.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${persona.nombre} ya registro asistencia'),
        ),
      );
      return;
    }
    setState(() {
      _empleado = persona;
      _foto = null;
      _busqueda.clear();
    });
  }

  String _personaSubtitle(Empleado persona) {
    final partes = <String>[
      persona.tipoPersonaLabel,
      if (persona.empresaNombre != null && persona.empresaNombre!.isNotEmpty)
        persona.empresaNombre!,
      persona.documentoLabel,
    ];
    return partes.join(' · ');
  }

  Widget _personaListTileSubtitle(Empleado persona) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (persona.cargo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              'Cargo: ${persona.cargo}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        Text(_personaSubtitle(persona)),
      ],
    );
  }

  Future<void> _tomarFoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 75,
    );
    if (image != null && mounted) {
      setState(() => _foto = File(image.path));
    }
  }

  Future<void> _guardar() async {
    if (_capacitacion?.id == null ||
        _empleado?.id == null ||
        _foto == null) {
      return;
    }

    if (!CapacitacionService.instance.puedeMarcarHoy(_capacitacion!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta capacitacion ya no acepta marcaciones'),
        ),
      );
      return;
    }

    final yaAsistio = await DbHelper.instance.empleadoYaAsistioCapacitacion(
      _capacitacion!.id!,
      _empleado!.id!,
    );
    if (yaAsistio) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_empleado!.nombre} ya registro asistencia'),
          ),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final fotoPath = await PhotoService.instance.saveCapacitacionAsistenciaPhoto(
        _foto!,
        _capacitacion!.id!,
        _empleado!.id!,
      );

      await DbHelper.instance.insertAsistenciaCapacitacion(
        AsistenciaCapacitacion(
          capacitacionId: _capacitacion!.id!,
          empleadoId: _empleado!.id!,
          fechaHora: DateTime.now(),
          fotoPath: fotoPath,
          empleadoCargo: _empleado!.cargo,
          empleadoNombre: _empleado!.nombre,
          empleadoTipoDocumento: _empleado!.tipoDocumento,
          empleadoNumeroDocumento: _empleado!.numeroDocumento,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _empleado!.cargo.isNotEmpty
                  ? 'Asistencia registrada para ${_empleado!.nombre} (${_empleado!.cargo})'
                  : 'Asistencia registrada para ${_empleado!.nombre}',
            ),
          ),
        );
        setState(() {
          _asistieronIds.add(_empleado!.id!);
          _empleado = null;
          _foto = null;
          _busqueda.clear();
        });
      }
    } on DatabaseException catch (e) {
      if (mounted) {
        if (e.isUniqueConstraintError()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_empleado!.nombre} ya registro asistencia'),
            ),
          );
          setState(() {
            if (_empleado?.id != null) {
              _asistieronIds.add(_empleado!.id!);
            }
            _empleado = null;
            _foto = null;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _canSave =>
      _capacitacion != null &&
      _empleado != null &&
      _foto != null &&
      !_saving;

  @override
  Widget build(BuildContext context) {
    final filtradas = _personasFiltradas;
    final buscando = _busqueda.text.trim().isNotEmpty;
    final dateFormat = DateFormat('dd/MM/yyyy');

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_capacitaciones.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No hay capacitaciones abiertas para hoy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            const SectionTitle('1. Capacitacion'),
            DropdownButtonFormField<Capacitacion>(
              initialValue: _capacitacion,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Seleccione capacitacion',
              ),
              items: _capacitaciones
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text('${c.nombre} (${dateFormat.format(c.fecha)})'),
                    ),
                  )
                  .toList(),
              onChanged: _onCapacitacionSelected,
            ),
            if (_capacitacion != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capacitacion!.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Expositor: ${_capacitacion!.expositor}'),
                      Text('Temas: ${_capacitacion!.temas}'),
                      if (_capacitacion!.empresaNombre != null)
                        Text('Organiza: ${_capacitacion!.empresaNombre}'),
                      const SizedBox(height: 4),
                      const Text(
                        'Pueden asistir internos y externos de cualquier empresa.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const SectionTitle('2. Persona'),
            PersonaSearchField(
              controller: _busqueda,
              hintText: 'ESCRIBA NOMBRE, EMPRESA, CARGO O DOCUMENTO...',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (_capacitacion == null)
              const InfoText('Seleccione una capacitacion primero')
            else if (_empleado != null) ...[
              Card(
                color: Colors.blue.shade50,
                child: ListTile(
                  title: Text(
                    _empleado!.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: _personaListTileSubtitle(_empleado!),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _empleado = null;
                      _foto = null;
                    }),
                  ),
                ),
              ),
            ] else if (!buscando)
              Text(
                'Escriba en el buscador para encontrar a la persona',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade700,
                    ),
              )
            else if (filtradas.isEmpty)
              const InfoText('Sin coincidencias')
            else ...[
              if (_hayMasCoincidencias)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Hay mas de $_maxResultadosBusqueda coincidencias. '
                    'Acote la busqueda.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.orange.shade800,
                        ),
                  ),
                ),
              ...filtradas.map(
                (persona) => Card(
                  child: ListTile(
                    title: Text(persona.nombre),
                    subtitle: _personaListTileSubtitle(persona),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _seleccionarPersona(persona),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const SectionTitle('3. Foto'),
            if (_foto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _foto!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _empleado == null ? null : _tomarFoto,
              icon: const Icon(Icons.camera_alt),
              label: Text(_foto == null ? 'Tomar foto' : 'Tomar otra foto'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _canSave ? _guardar : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const InfoText('Registrar asistencia'),
            ),
          ),
        ),
      ),
    );
  }
}
