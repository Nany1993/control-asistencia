import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/db_helper.dart';
import '../../models/empleado.dart';
import '../../models/empresa.dart';
import '../../models/tipo_documento.dart';
import '../../models/turno.dart';
import '../../utils/persona_search.dart';

class PersonasAdminScreen extends StatefulWidget {
  const PersonasAdminScreen({
    super.key,
    required this.esExterno,
    required this.titulo,
    required this.etiquetaNuevo,
  });

  final bool esExterno;
  final String titulo;
  final String etiquetaNuevo;

  @override
  State<PersonasAdminScreen> createState() => _PersonasAdminScreenState();
}

class _PersonasAdminScreenState extends State<PersonasAdminScreen> {
  final _busqueda = TextEditingController();

  List<Empresa> _empresas = [];
  List<Empleado> _personas = [];
  int? _empresaId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final empresas = await DbHelper.instance.getEmpresas();
    if (mounted) {
      setState(() {
        _empresas = empresas;
        _empresaId = empresas.isNotEmpty ? empresas.first.id : null;
      });
      await _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DbHelper.instance.getEmpleados(
      empresaId: _empresaId,
      esExterno: widget.esExterno,
    );
    if (mounted) {
      setState(() {
        _personas = data;
        _loading = false;
      });
    }
  }

  List<Empleado> get _filtradas {
    final q = _busqueda.text;
    return _personas.where((p) {
      return PersonaSearch.matches(
        nombre: p.nombre,
        tipoDocumento: p.tipoDocumento,
        numeroDocumento: p.numeroDocumento,
        query: q,
      );
    }).toList();
  }

  Future<void> _openForm([Empleado? persona]) async {
    if (_empresas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero cree una empresa')),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PersonaFormDialog(
        empresas: _empresas,
        empresaIdInicial: persona?.empresaId ?? _empresaId ?? _empresas.first.id!,
        esExterno: widget.esExterno,
        persona: persona,
        permitirCambiarEmpresa: widget.esExterno,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(Empleado persona) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar ${widget.esExterno ? 'externo' : 'empleado'}'),
        content: Text(
          'Se eliminaran los registros de "${persona.nombre}". Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await DbHelper.instance.deleteEmpleado(persona.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: Text(widget.etiquetaNuevo),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<int?>(
              initialValue: _empresaId,
              decoration: const InputDecoration(
                labelText: 'Empresa',
                border: OutlineInputBorder(),
              ),
              items: _empresas
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.nombre),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                setState(() => _empresaId = value);
                await _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: PersonaSearchField(
              controller: _busqueda,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtradas.isEmpty
                    ? Center(
                        child: Text(
                          _personas.isEmpty
                              ? 'No hay registros en esta empresa'
                              : 'Sin coincidencias para la busqueda',
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtradas.length,
                        itemBuilder: (context, index) {
                          final persona = filtradas[index];
                          final subtitulo = widget.esExterno
                              ? '${persona.documentoLabel} · ${persona.activo ? 'Activo' : 'Inactivo'}'
                              : [
                                  persona.documentoLabel,
                                  if (persona.turnoNombre != null) 'Turno: ${persona.turnoNombre}',
                                  persona.activo ? 'Activo' : 'Inactivo',
                                ].join(' · ');
                          return ListTile(
                            title: Text(persona.nombre),
                            subtitle: Text(subtitulo),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') _openForm(persona);
                                if (value == 'delete') _delete(persona);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('Editar')),
                                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PersonaFormDialog extends StatefulWidget {
  const _PersonaFormDialog({
    required this.empresas,
    required this.empresaIdInicial,
    required this.esExterno,
    this.persona,
    required this.permitirCambiarEmpresa,
  });

  final List<Empresa> empresas;
  final int empresaIdInicial;
  final bool esExterno;
  final Empleado? persona;
  final bool permitirCambiarEmpresa;

  @override
  State<_PersonaFormDialog> createState() => _PersonaFormDialogState();
}

class _PersonaFormDialogState extends State<_PersonaFormDialog> {
  late final TextEditingController _nombre;
  late final TextEditingController _numeroDocumento;
  late int _empresaId;
  late String _tipoDocumento;
  late bool _activo;
  int? _turnoId;
  List<Turno> _turnos = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.persona?.nombre ?? '');
    _numeroDocumento = TextEditingController(text: widget.persona?.numeroDocumento ?? '');
    _empresaId = widget.persona?.empresaId ?? widget.empresaIdInicial;
    _tipoDocumento = widget.persona?.tipoDocumento ?? TipoDocumento.cc.codigo;
    _activo = widget.persona?.activo ?? true;
    _turnoId = widget.persona?.turnoId;
    if (!widget.esExterno) {
      _loadTurnos();
    }
  }

  Future<void> _loadTurnos() async {
    final turnos = await DbHelper.instance.getTurnos(empresaId: _empresaId);
    if (mounted) {
      setState(() {
        _turnos = turnos;
        if (_turnoId != null && !turnos.any((t) => t.id == _turnoId)) {
          _turnoId = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _numeroDocumento.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    final numero = _numeroDocumento.text.trim();

    if (nombre.isEmpty || numero.isEmpty) {
      setState(() => _error = 'Nombre y numero de documento son obligatorios');
      return;
    }
    if (!widget.esExterno && _turnoId == null) {
      setState(() => _error = 'Seleccione un turno para el empleado interno');
      return;
    }

    if (widget.persona == null) {
      await DbHelper.instance.insertEmpleado(
        Empleado(
          empresaId: _empresaId,
          nombre: nombre,
          tipoDocumento: _tipoDocumento,
          numeroDocumento: numero,
          esExterno: widget.esExterno,
          turnoId: widget.esExterno ? null : _turnoId,
          activo: _activo,
          createdAt: DateTime.now(),
        ),
      );
    } else {
      await DbHelper.instance.updateEmpleado(
        widget.persona!.copyWith(
          empresaId: _empresaId,
          nombre: nombre,
          tipoDocumento: _tipoDocumento,
          numeroDocumento: numero,
          turnoId: widget.esExterno ? null : _turnoId,
          clearTurnoId: widget.esExterno,
          activo: _activo,
        ),
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tituloNuevo = widget.esExterno ? 'Nuevo externo' : 'Nuevo empleado';
    final tituloEditar = widget.esExterno ? 'Editar externo' : 'Editar empleado';

    return AlertDialog(
      title: Text(widget.persona == null ? tituloNuevo : tituloEditar),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.permitirCambiarEmpresa) ...[
              DropdownButtonFormField<int>(
                initialValue: _empresaId,
                decoration: const InputDecoration(
                  labelText: 'Empresa',
                  border: OutlineInputBorder(),
                ),
                items: widget.empresas
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.nombre),
                      ),
                    )
                    .toList(),
                onChanged: (v) async {
                  setState(() => _empresaId = v ?? _empresaId);
                  if (!widget.esExterno) await _loadTurnos();
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _tipoDocumento,
              decoration: const InputDecoration(
                labelText: 'Tipo de documento',
                border: OutlineInputBorder(),
              ),
              items: TipoDocumento.valores
                  .map(
                    (t) => DropdownMenuItem(
                      value: t.codigo,
                      child: Text('${t.codigo} - ${t.label}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _tipoDocumento = v ?? TipoDocumento.cc.codigo),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _numeroDocumento,
              decoration: const InputDecoration(labelText: 'Numero de documento'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            if (!widget.esExterno) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _turnoId,
                decoration: const InputDecoration(
                  labelText: 'Turno',
                  border: OutlineInputBorder(),
                ),
                items: _turnos
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text(t.resumenLabel),
                      ),
                    )
                    .toList(),
                onChanged: _turnos.isEmpty ? null : (v) => setState(() => _turnoId = v),
              ),
              if (_turnos.isEmpty)
                Text(
                  'Cree turnos en Admin → Turnos',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
            ),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
