import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
import '../../widgets/info_text.dart';
import '../../widgets/salida_anticipada_dialog.dart';

class AsistenciaScreen extends StatefulWidget {
  const AsistenciaScreen({super.key});

  @override
  State<AsistenciaScreen> createState() => _AsistenciaScreenState();
}

class _AsistenciaScreenState extends State<AsistenciaScreen> {
  final _picker = ImagePicker();
  final _busqueda = TextEditingController();

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

  static const _maxResultadosBusqueda = 10;

  List<Empleado> get _coincidenciasBusqueda {
    if (_busqueda.text.trim().isEmpty) return [];
    return _personas.where((p) {
      return PersonaSearch.matches(
        nombre: p.nombre,
        tipoDocumento: p.tipoDocumento,
        numeroDocumento: p.numeroDocumento,
        cargo: p.cargo,
        query: _busqueda.text,
      );
    }).toList();
  }

  List<Empleado> get _personasFiltradas =>
      _coincidenciasBusqueda.take(_maxResultadosBusqueda).toList();

  bool get _hayMasCoincidencias =>
      _coincidenciasBusqueda.length > _maxResultadosBusqueda;

  void _seleccionarPersona(Empleado persona) {
    setState(() {
      _empleado = persona;
      _busqueda.clear();
    });
    _onPersonaSelected(persona);
  }

  Widget _personaSeleccionadaCard(Empleado persona) {
    final subtitulo = persona.esExterno
        ? [
            persona.documentoLabel,
            if (persona.cargo.isNotEmpty) persona.cargo,
          ].join(' · ')
        : [
            persona.documentoLabel,
            if (persona.cargo.isNotEmpty) persona.cargo,
            if (persona.turnosNombre != null) 'Turnos: ${persona.turnosNombre}',
          ].join(' · ');
    return Card(
      color: Colors.blue.shade50,
      child: ListTile(
        title: Text(persona.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitulo),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _empleado = null;
            _tipo = null;
            _ultimoRegistro = null;
            _turnosAsignados = [];
            _turno = null;
            _foto = null;
          }),
        ),
      ),
    );
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
          content: InfoText(
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

  Future<Turno?> _turnoParaCierre(Registro entradaPendiente) async {
    if (entradaPendiente.turnoId != null) {
      final turno = await DbHelper.instance.getTurno(entradaPendiente.turnoId!);
      if (turno != null) return turno;
    }
    if (_turnosAsignados.isNotEmpty) {
      return TurnoEvaluator.turnoParaFecha(
        _turnosAsignados,
        entradaPendiente.fechaHora,
      );
    }
    return _turno;
  }

  Future<Registro?> _cerrarEntradaPendienteSiAplica(DateTime ahora) async {
    if (_tipo != TipoMarcacion.entrada) return _ultimoRegistro;
    if (!MarcacionValidator.requiereCierreSalidaPendiente(_ultimoRegistro, ahora: ahora)) {
      return _ultimoRegistro;
    }

    final entradaPendiente = _ultimoRegistro!;
    final turnoCierre = await _turnoParaCierre(entradaPendiente);
    final salidaAuto = Registro(
      empresaId: entradaPendiente.empresaId,
      empleadoId: entradaPendiente.empleadoId,
      tipo: TipoMarcacion.salida,
      fechaHora: MarcacionValidator.fechaCierreSalidaPendiente(
        entradaPendiente,
        turno: turnoCierre,
      ),
      fotoPath: PhotoService.sistemaSinFoto,
      observacion: MarcacionValidator.observacionCierreAutomatico,
      turnoId: turnoCierre?.id ?? entradaPendiente.turnoId,
      empresaNombre: entradaPendiente.empresaNombre ?? _empresa!.nombre,
      empleadoCargo: entradaPendiente.empleadoCargo ?? _empleado!.cargo,
      empleadoNombre: entradaPendiente.empleadoNombre ?? _empleado!.nombre,
      empleadoTipoDocumento:
          entradaPendiente.empleadoTipoDocumento ?? _empleado!.tipoDocumento,
      empleadoNumeroDocumento:
          entradaPendiente.empleadoNumeroDocumento ?? _empleado!.numeroDocumento,
    );

    await DbHelper.instance.insertRegistro(salidaAuto);
    return salidaAuto;
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
      var ultimoParaEvaluar = _ultimoRegistro;
      var cierreAutomatico = false;

      if (_tipo == TipoMarcacion.entrada) {
        final cerrado = await _cerrarEntradaPendienteSiAplica(ahora);
        if (cerrado != _ultimoRegistro) {
          ultimoParaEvaluar = cerrado;
          cierreAutomatico = true;
        }
      }

      MotivoSalida? motivoSalida;
      String? radicado;
      String? notaSalida;

      if (!_esExterno &&
          _turno != null &&
          _tipo == TipoMarcacion.salida &&
          TurnoEvaluator.esSalidaAnticipada(turno: _turno!, fechaHora: ahora)) {
        setState(() => _saving = false);
        if (!mounted) return;
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

      String? observacion;
      if (!_esExterno && _turno != null) {
        observacion = TurnoEvaluator.evaluarMarcacion(
          turno: _turno,
          tipo: _tipo!,
          fechaHora: ahora,
          ultimoRegistro: ultimoParaEvaluar,
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
          empresaNombre: _empresa!.nombre,
          empleadoCargo: _empleado!.cargo,
          empleadoNombre: _empleado!.nombre,
          empleadoTipoDocumento: _empleado!.tipoDocumento,
          empleadoNumeroDocumento: _empleado!.numeroDocumento,
        ),
      );

      if (mounted) {
        final extra = observacion != null ? ' ($observacion)' : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: InfoText(
              cierreAutomatico
                  ? 'Salida automatica del dia anterior (No registro salida). '
                      '${_tipo!.label} registrada para ${_empleado!.nombre}$extra'
                  : '${_tipo!.label} registrada para ${_empleado!.nombre}$extra',
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
    final buscando = _busqueda.text.trim().isNotEmpty;

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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    const SectionTitle('1. Empresa'),
                    DropdownButtonFormField<Empresa>(
                      initialValue: _empresa,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Seleccione empresa',
                      ),
                      items: _empresas
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e.displayLabel)),
                          )
                          .toList(),
                      onChanged: _onEmpresaSelected,
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('2. Tipo de persona'),
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
                    SectionTitle(_esExterno ? '3. Externo' : '3. Empleado'),
                    PersonaSearchField(
                      controller: _busqueda,
                      hintText: 'ESCRIBA NOMBRE, DOCUMENTO O CARGO...',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    if (_empresa == null)
                      const InfoText('Seleccione una empresa primero')
                    else if (_empleado != null) ...[
                      _personaSeleccionadaCard(_empleado!),
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
                        (persona) {
                          final subtitulo = persona.esExterno
                              ? [
                                  persona.documentoLabel,
                                  if (persona.cargo.isNotEmpty) persona.cargo,
                                ].join(' · ')
                              : [
                                  persona.documentoLabel,
                                  if (persona.cargo.isNotEmpty) persona.cargo,
                                  if (persona.turnosNombre != null)
                                    'Turnos: ${persona.turnosNombre}',
                                ].join(' · ');
                          return Card(
                            child: ListTile(
                              title: Text(persona.nombre),
                              subtitle: Text(subtitulo),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _seleccionarPersona(persona),
                            ),
                          );
                        },
                      ),
                    ],
                    if (_turnosAsignados.isNotEmpty && !_esExterno && _empleado != null) ...[
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
                    if (siguienteTipo != null && _empleado != null) ...[
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
                    const SectionTitle('4. Tipo'),
                    Row(
                      children: [
                        _tipoButton(TipoMarcacion.entrada),
                        _tipoButton(TipoMarcacion.salida),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionTitle('5. Foto'),
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
      bottomNavigationBar: _loading || _empresas.isEmpty
          ? null
          : SafeArea(
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
                    label: const InfoText('Registrar marcacion'),
                  ),
                ),
              ),
            ),
    );
  }
}
