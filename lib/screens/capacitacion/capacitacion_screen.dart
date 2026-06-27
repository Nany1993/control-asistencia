import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../models/capacitacion.dart';
import '../../models/empleado.dart';
import '../../models/empresa.dart';
import '../../models/asistencia_capacitacion.dart';
import '../../services/capacitacion_service.dart';
import '../../services/photo_service.dart';
import '../../utils/persona_search.dart';

class CapacitacionScreen extends StatefulWidget {
  const CapacitacionScreen({super.key});

  @override
  State<CapacitacionScreen> createState() => _CapacitacionScreenState();
}

class _CapacitacionScreenState extends State<CapacitacionScreen> {
  final _picker = ImagePicker();
  final _busqueda = TextEditingController();

  List<Capacitacion> _capacitaciones = [];
  List<Empresa> _empresas = [];
  List<Empleado> _personas = [];
  Capacitacion? _capacitacion;
  Empresa? _empresa;
  Empleado? _empleado;
  File? _foto;
  bool _loading = true;
  bool _saving = false;
  bool _esExterno = false;

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
    final empresas = await DbHelper.instance.getEmpresas(soloActivas: true);
    if (mounted) {
      setState(() {
        _capacitaciones = caps;
        _empresas = empresas;
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
    _empresa = null;
    _empleado = null;
    _personas = [];
    _foto = null;
    _busqueda.clear();
  }

  Future<void> _onCapacitacionSelected(Capacitacion? cap) async {
    setState(() {
      _capacitacion = cap;
      _empleado = null;
      _foto = null;
      _busqueda.clear();
    });

    if (cap == null) {
      setState(() {
        _empresa = null;
        _personas = [];
      });
      return;
    }

    if (cap.empresaId != null) {
      final empresa = await DbHelper.instance.getEmpresa(cap.empresaId!);
      await _cargarPersonas(empresa);
    } else {
      setState(() {
        _empresa = null;
        _personas = [];
      });
    }
  }

  Future<void> _onEmpresaSelected(Empresa? empresa) async {
    setState(() {
      _empresa = empresa;
      _empleado = null;
      _foto = null;
      _busqueda.clear();
    });
    await _cargarPersonas(empresa);
  }

  Future<void> _cargarPersonas(Empresa? empresa) async {
    if (empresa?.id == null) {
      setState(() => _personas = []);
      return;
    }
    final personas = await DbHelper.instance.getEmpleados(
      empresaId: empresa!.id,
      soloActivos: true,
      esExterno: _esExterno,
    );
    if (mounted) setState(() => _personas = personas);
  }

  Future<void> _onTipoPersonaChanged(bool esExterno) async {
    if (_esExterno == esExterno) return;
    setState(() {
      _esExterno = esExterno;
      _empleado = null;
      _foto = null;
      _busqueda.clear();
    });
    await _cargarPersonas(_empresa);
  }

  List<Empleado> get _personasFiltradas {
    return _personas.where((p) {
      return PersonaSearch.matches(
        nombre: p.nombre,
        tipoDocumento: p.tipoDocumento,
        numeroDocumento: p.numeroDocumento,
        query: _busqueda.text,
      );
    }).toList();
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
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asistencia registrada para ${_empleado!.nombre}',
            ),
          ),
        );
        setState(() {
          _empleado = null;
          _foto = null;
          _busqueda.clear();
        });
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

  bool get _needsEmpresaPicker =>
      _capacitacion != null && _capacitacion!.empresaId == null;

  bool get _canSave =>
      _capacitacion != null &&
      _empleado != null &&
      _foto != null &&
      !_saving &&
      (!_needsEmpresaPicker || _empresa != null);

  @override
  Widget build(BuildContext context) {
    final filtradas = _personasFiltradas;
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle('1. Capacitacion'),
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
                      Text('Empresa: ${_capacitacion!.empresaNombre}'),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_needsEmpresaPicker) ...[
            const _SectionTitle('2. Empresa'),
            DropdownButtonFormField<Empresa>(
              initialValue: _empresa,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Seleccione empresa',
              ),
              items: _empresas
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.nombre)))
                  .toList(),
              onChanged: _onEmpresaSelected,
            ),
            const SizedBox(height: 20),
          ],
          _SectionTitle(_needsEmpresaPicker ? '3. Persona' : '2. Persona'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Internos'), icon: Icon(Icons.badge)),
              ButtonSegment(value: true, label: Text('Externos'), icon: Icon(Icons.person_outline)),
            ],
            selected: {_esExterno},
            onSelectionChanged: _capacitacion == null ||
                    (_needsEmpresaPicker && _empresa == null)
                ? null
                : (s) => _onTipoPersonaChanged(s.first),
          ),
          const SizedBox(height: 12),
          PersonaSearchField(
            controller: _busqueda,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (_capacitacion == null)
            const Text('Seleccione una capacitacion primero')
          else if (_needsEmpresaPicker && _empresa == null)
            const Text('Seleccione una empresa primero')
          else if (filtradas.isEmpty)
            Text(
              _personas.isEmpty
                  ? 'No hay personas en esta empresa'
                  : 'Sin coincidencias',
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtradas.length,
                itemBuilder: (context, index) {
                  final persona = filtradas[index];
                  final selected = _empleado?.id == persona.id;
                  return Card(
                    color: selected ? Colors.blue.shade50 : null,
                    child: ListTile(
                      selected: selected,
                      title: Text(persona.nombre),
                      subtitle: Text(persona.documentoLabel),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : null,
                      onTap: () => setState(() {
                        _empleado = persona;
                        _foto = null;
                      }),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          _SectionTitle(_needsEmpresaPicker ? '4. Foto' : '3. Foto'),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _canSave ? _guardar : null,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Registrar asistencia'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
