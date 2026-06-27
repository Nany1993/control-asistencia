import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../models/empleado.dart';
import '../../models/empresa.dart';
import '../../models/motivo_salida.dart';
import '../../models/registro.dart';
import '../../models/turno.dart';
import '../../services/marcacion_validator.dart';
import '../../services/photo_service.dart';
import '../../services/turno_evaluator.dart';
import '../../utils/persona_search.dart';
import '../../widgets/salida_anticipada_dialog.dart';

class AsistenciaScreen extends StatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  final _picker = ImagePicker();
  final _busqueda = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  List<Empresa> _empresas = [];
  List<Empleado> _personas = [];
  Empresa? _empresa;
  Empleado? _empleado;
  TipoMarcacion? _tipo;
  Registro? _ultimoRegistro;
  List<Turno> _turnosAsignados = [];
  Turno? _turno;
  File? _foto;
  bool _loading = true;
  bool _saving = false;
  bool _esExterno = false;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
    _loadEmpresas();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _loadEmpresas() async {
    setState(() => _loading = true);
    final empresas = await DbHelper.instance.getEmpresas(soloActivas: true);
    if (mounted) {
      setState(() {
        _empresas = empresas;
        _loading = false;
      });
    }
  }

  Future<void> _cargarPersonas() async {
    if (_empresa?.id == null) {
      setState(() => _personas = []);
      return;
    }
    final personas = await DbHelper.instance.getEmpleados(
      empresaId: _empresa!.id,
      soloActivos: true,
      esExterno: _esExterno,
    );
    if (mounted) setState(() => _personas = personas);
  }

  Future<void> _onEmpresaSelected(Empresa? empresa) async {
    setState(() {
      _empresa = empresa;
      _empleado = null;
      _personas = [];
      _tipo = null;
      _ultimoRegistro = null;
      _turnosAsignados = [];
      _turno = null;
      _foto = null;
      _busqueda.clear();
    });
    await _cargarPersonas();
  }

  Future<void> _onTipoPersonaChanged(bool esExterno) async {
    if (_esExterno == esExterno) return;
    setState(() {
      _esExterno = esExterno;
      _empleado = null;
      _tipo = null;
      _ultimoRegistro = null;
      _turnosAsignados = [];
      _turno = null;
      _foto = null;
      _busqueda.clear();
    });
    await _cargarPersonas();
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

  Future<void> _onPersonaSelected(Empleado persona) async {
    setState(() {
      _empleado = persona;
      _tipo = null;
      _foto = null;
      _ultimoRegistro = null;
      _turnosAsignados = [];
      _turno = null;
    });
    final ultimo = await DbHelper.instance.getUltimoRegistroEmpleado(persona.id!);
    List<Turno> turnos = [];
    Turno? turnoHoy;
    if (!persona.esExterno) {
      turnos = await DbHelper.instance.getTurnosForEmpleado(persona.id!);
      turnoHoy = TurnoEvaluator.turnoParaFecha(turnos, DateTime.now());
    }
    if (mounted) {
      setState(() {
        _ultimoRegistro = ultimo;
        _turnosAsignados = turnos;
        _turno = turnoHoy;
        _tipo = MarcacionValidator.tipoPermitido(ultimo);
      });
    }
  }

  void _seleccionarTipo(TipoMarcacion tipo) {
    if (!MarcacionValidator.puedeMarcar(_ultimoRegistro, tipo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            MarcacionValidator.mensajeBloqueo(_ultimoRegistro, tipo),
          ),
        ),
      );
      return;
    }
    setState(() => _tipo = tipo);
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
    if (_empresa?.id == null || _empleado?.id == null || _tipo == null || _foto == null) {
      return;
    }

    if (!MarcacionValidator.puedeMarcar(_ultimoRegistro, _tipo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            MarcacionValidator.mensajeBloqueo(_ultimoRegistro, _tipo!),
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final ahora = DateTime.now();
      MotivoSalida? motivoSalida;
      String? radicado;
      String? notaSalida;

      if (!_esExterno &&
          _turno != null &&
          _tipo == TipoMarcacion.salida &&
          TurnoEvaluator.esSalidaAnticipada(turno: _turno!, fechaHora: ahora)) {
        if (TurnoEvaluator.esHorarioAlmuerzo(turno: _turno!, fechaHora: ahora)) {
          motivoSalida = MotivoSalida.almuerzo;
        } else {
          setState(() => _saving = false);
          final data = await showDialog<SalidaAnticipadaData>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const SalidaAnticipadaDialog(),
          );
          if (data == null || !mounted) return;
          motivoSalida = data.motivo;
          radicado = data.radicado;
          notaSalida = data.nota;
          setState(() => _saving = true);
        }
      }

      String? observacion;
      if (!_esExterno && _turno != null) {
        observacion = TurnoEvaluator.evaluarMarcacion(
          turno: _turno,
          tipo: _tipo!,
          fechaHora: ahora,
          ultimoRegistro: _ultimoRegistro,
          motivoSalida: motivoSalida,
        );
        if (radicado != null && radicado.isNotEmpty) {
          observacion = '${observacion ?? ''} · Radicado: $radicado'.trim();
        }
        if (notaSalida != null && notaSalida.isNotEmpty) {
          observacion = '${observacion ?? ''} · $notaSalida'.trim();
        }
      }

      final fotoPath = await PhotoService.instance.savePhoto(
        _foto!,
        _empresa!.id!,
        _empleado!.id!,
      );

      await DbHelper.instance.insertRegistro(
        Registro(
          empresaId: _empresa!.id!,
          empleadoId: _empleado!.id!,
          tipo: _tipo!,
          fechaHora: ahora,
          fotoPath: fotoPath,
          observacion: observacion,
          motivoSalida: motivoSalida?.value,
          radicado: radicado,
          turnoId: _turno?.id,
        ),
      );

      if (mounted) {
        final extra = observacion != null ? ' ($observacion)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_tipo!.label} registrada para ${_empleado!.nombre}$extra',
            ),
          ),
        );
        setState(() {
          _empleado = null;
          _tipo = null;
          _ultimoRegistro = null;
          _turnosAsignados = [];
          _turno = null;
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

  bool get _canSave =>
      _empresa != null &&
      _empleado != null &&
      _tipo != null &&
      _foto != null &&
      !_saving &&
      MarcacionValidator.puedeMarcar(_ultimoRegistro, _tipo!);

  Widget _tipoButton(TipoMarcacion tipo) {
    final selected = _tipo == tipo;
    final permitido = MarcacionValidator.puedeMarcar(_ultimoRegistro, tipo);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          onPressed: _empleado == null || !permitido ? null : () => _seleccionarTipo(tipo),
          style: FilledButton.styleFrom(
            backgroundColor: selected ? Colors.blue : null,
            foregroundColor: selected ? Colors.white : null,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            tipo.label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final siguienteTipo = _empleado != null
        ? MarcacionValidator.tipoPermitido(_ultimoRegistro)
        : null;
    final filtradas = _personasFiltradas;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _empresas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No hay empresas activas. Ingrese al modulo administrador para crear una.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _SectionTitle('1. Empresa'),
                    DropdownButtonFormField<Empresa>(
                      initialValue: _empresa,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Seleccione empresa',
                      ),
                      items: _empresas
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e.nombre)),
                          )
                          .toList(),
                      onChanged: _onEmpresaSelected,
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('2. Tipo de persona'),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Internos'), icon: Icon(Icons.badge)),
                        ButtonSegment(value: true, label: Text('Externos'), icon: Icon(Icons.person_outline)),
                      ],
                      selected: {_esExterno},
                      onSelectionChanged: _empresa == null
                          ? null
                          : (s) => _onTipoPersonaChanged(s.first),
                    ),
                    const SizedBox(height: 20),
                    _SectionTitle(_esExterno ? '3. Externo' : '3. Empleado'),
                    PersonaSearchField(
                      controller: _busqueda,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    if (_empresa == null)
                      const Text('Seleccione una empresa primero')
                    else if (filtradas.isEmpty)
                      Text(
                        _personas.isEmpty
                            ? 'No hay ${_esExterno ? 'externos' : 'empleados'} en esta empresa'
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
                            final subtitulo = persona.esExterno
                                ? persona.documentoLabel
                                : [
                                    persona.documentoLabel,
                                    if (persona.turnosNombre != null)
                                      'Turnos: ${persona.turnosNombre}',
                                  ].join(' · ');
                            return Card(
                              color: selected ? Colors.blue.shade50 : null,
                              child: ListTile(
                                selected: selected,
                                title: Text(persona.nombre),
                                subtitle: Text(subtitulo),
                                trailing: selected
                                    ? const Icon(Icons.check_circle, color: Colors.blue)
                                    : null,
                                onTap: _empresa == null
                                    ? null
                                    : () => _onPersonaSelected(persona),
                              ),
                            );
                          },
                        ),
                      ),
                    if (_turnosAsignados.isNotEmpty && !_esExterno) ...[
                      const SizedBox(height: 8),
                      Card(
                        color: _turno != null ? Colors.blue.shade50 : Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_turno != null)
                                Text(
                                  'Turno de hoy: ${_turno!.nombre} (${_turno!.horarioLabel}) · '
                                  '${diasSemanaTexto(_turno!.diasSemana)}'
                                  '${_turno!.tieneHorarioAlmuerzo ? ' · Almuerzo ${_turno!.horaAlmuerzoInicio}-${_turno!.horaAlmuerzoFin}' : ''}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                )
                              else
                                Text(
                                  'Hoy no tiene turno asignado. Turnos: '
                                  '${_turnosAsignados.map((t) => t.nombre).join(', ')}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_ultimoRegistro != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Ultima marcacion: ${_ultimoRegistro!.tipo.label} '
                        'el ${_dateFormat.format(_ultimoRegistro!.fechaHora)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (siguienteTipo != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Siguiente marcacion permitida: ${siguienteTipo.label}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _SectionTitle('4. Tipo'),
                    Row(
                      children: [
                        _tipoButton(TipoMarcacion.entrada),
                        _tipoButton(TipoMarcacion.salida),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('5. Foto'),
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
                      label: const Text('Registrar marcacion'),
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
