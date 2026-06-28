import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../models/empleado.dart';
import '../../models/empresa.dart';
import '../../models/registro.dart';
import '../../services/photo_service.dart';
import '../../utils/persona_search.dart';

class RegistrosScreen extends StatefulWidget {
  const RegistrosScreen({super.key});

  @override
  State<RegistrosScreen> createState() => _RegistrosScreenState();
}

class _RegistrosScreenState extends State<RegistrosScreen> {
  final _busquedaEmpleado = TextEditingController();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  List<Empresa> _empresas = [];
  List<Empleado> _empleados = [];
  List<Registro> _registros = [];
  int? _empresaId;
  int? _empleadoId;
  bool? _filtroExterno;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _busquedaEmpleado.addListener(() => setState(() {}));
    _init();
  }

  @override
  void dispose() {
    _busquedaEmpleado.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final empresas = await DbHelper.instance.getEmpresas();
    if (mounted) {
      setState(() => _empresas = empresas);
      await _loadEmpleados();
      await _load();
    }
  }

  Future<void> _loadEmpleados() async {
    final empleados = await DbHelper.instance.getEmpleados(
      empresaId: _empresaId,
      esExterno: _filtroExterno,
    );
    if (mounted) {
      setState(() {
        _empleados = empleados;
        if (_empleadoId != null && !empleados.any((e) => e.id == _empleadoId)) {
          _empleadoId = null;
        }
      });
    }
  }

  List<Empleado> get _empleadosFiltrados {
    return _empleados.where((e) {
      return PersonaSearch.matches(
        nombre: e.nombre,
        tipoDocumento: e.tipoDocumento,
        numeroDocumento: e.numeroDocumento,
        cargo: e.cargo,
        query: _busquedaEmpleado.text,
      );
    }).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DbHelper.instance.getRegistros(
      empresaId: _empresaId,
      empleadoId: _empleadoId,
      esExterno: _filtroExterno,
    );
    if (mounted) {
      setState(() {
        _registros = data;
        _loading = false;
      });
    }
  }

  Future<void> _onEmpresaChanged(int? value) async {
    setState(() {
      _empresaId = value;
      _empleadoId = null;
      _busquedaEmpleado.clear();
    });
    await _loadEmpleados();
    await _load();
  }

  Future<void> _onTipoPersonaChanged(bool? esExterno) async {
    setState(() {
      _filtroExterno = esExterno;
      _empleadoId = null;
      _busquedaEmpleado.clear();
    });
    await _loadEmpleados();
    await _load();
  }

  void _verFoto(Registro registro) {
    final esSistema = PhotoService.esFotoSistema(registro.fotoPath);
    final file = File(registro.fotoPath);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${registro.empleadoNombre ?? ''} · ${registro.tipoPersonaLabel} · ${registro.tipo.label}',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            if (!esSistema && file.existsSync())
              InteractiveViewer(
                child: Image.file(file, fit: BoxFit.contain),
              )
            else
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  esSistema
                      ? 'Marcacion automatica del sistema (sin foto)'
                      : 'Foto no encontrada en el dispositivo',
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _dateFormat.format(registro.fechaHora),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empleadosFiltrados = _empleadosFiltrados;

    return Scaffold(
      appBar: AppBar(title: const Text('Registros')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: DropdownButtonFormField<int?>(
              initialValue: _empresaId,
              decoration: const InputDecoration(
                labelText: 'Filtrar por empresa',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                ..._empresas.map(
                  (e) => DropdownMenuItem(value: e.id, child: Text(e.displayLabel)),
                ),
              ],
              onChanged: _onEmpresaChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<bool?>(
              segments: const [
                ButtonSegment<bool?>(value: null, label: Text('Todos')),
                ButtonSegment<bool?>(value: false, label: Text('Internos')),
                ButtonSegment<bool?>(value: true, label: Text('Externos')),
              ],
              selected: {_filtroExterno},
              onSelectionChanged: (s) => _onTipoPersonaChanged(s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PersonaSearchField(
              controller: _busquedaEmpleado,
              hintText: 'Buscar empleado o externo...',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<int?>(
              initialValue: _empleadoId,
              decoration: const InputDecoration(
                labelText: 'Filtrar por persona',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
                ...empleadosFiltrados.map(
                  (e) => DropdownMenuItem(
                    value: e.id,
                    child: Text('${e.tipoPersonaLabel}: ${e.nombreConDocumento}'),
                  ),
                ),
              ],
              onChanged: (value) async {
                setState(() => _empleadoId = value);
                await _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _registros.isEmpty
                    ? const Center(child: Text('No hay registros'))
                    : ListView.builder(
                        itemCount: _registros.length,
                        itemBuilder: (context, index) {
                          final r = _registros[index];
                          final doc = r.empleadoTipoDocumento != null &&
                                  r.empleadoNumeroDocumento != null
                              ? '${r.empleadoTipoDocumento} ${r.empleadoNumeroDocumento}'
                              : '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: r.tipo.value == 'entrada'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              child: Icon(
                                r.tipo.value == 'entrada'
                                    ? Icons.login
                                    : Icons.logout,
                                color: r.tipo.value == 'entrada'
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                            title: Text('${r.tipoPersonaLabel}: ${r.empleadoNombre ?? 'Persona'}'),
                            subtitle: Text(
                              [
                                if (doc.isNotEmpty) doc,
                                if (r.empleadoCargo != null &&
                                    r.empleadoCargo!.isNotEmpty)
                                  r.empleadoCargo!,
                                if (r.turnoNombre != null) 'Turno: ${r.turnoNombre}',
                                r.empresaNombre ?? '',
                                _dateFormat.format(r.fechaHora),
                                r.tipo.label,
                                if (r.motivoSalidaLabel != null) r.motivoSalidaLabel!,
                                if (r.radicado != null && r.radicado!.isNotEmpty)
                                  'Rad: ${r.radicado}',
                                if (r.observacion != null && r.observacion!.isNotEmpty)
                                  r.observacion!,
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                            trailing: const Icon(Icons.photo_camera),
                            onTap: () => _verFoto(r),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
