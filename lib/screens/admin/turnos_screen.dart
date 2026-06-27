import 'package:flutter/material.dart';

import '../../database/db_helper.dart';
import '../../models/empresa.dart';
import '../../models/turno.dart';

class TurnosScreen extends StatefulWidget {
  const TurnosScreen({super.key});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  List<Empresa> _empresas = [];
  List<Turno> _turnos = [];
  int? _empresaId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
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
    final data = await DbHelper.instance.getTurnos(empresaId: _empresaId);
    if (mounted) {
      setState(() {
        _turnos = data;
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Turno? turno]) async {
    if (_empresaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero cree una empresa')),
      );
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TurnoFormDialog(
        empresaId: _empresaId!,
        turno: turno,
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete(Turno turno) async {
    final asignados = await DbHelper.instance.countEmpleadosConTurno(turno.id!);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar turno'),
        content: Text(
          asignados > 0
              ? '"${turno.nombre}" tiene $asignados empleado(s) asignado(s). '
                  'Se quitara el turno de esos empleados. Continuar?'
              : 'Eliminar turno "${turno.nombre}"?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await DbHelper.instance.deleteTurno(turno.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Turnos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo turno'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<int?>(
              initialValue: _empresaId,
              decoration: const InputDecoration(
                labelText: 'Empresa',
                border: OutlineInputBorder(),
              ),
              items: _empresas
                  .map((e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)))
                  .toList(),
              onChanged: (v) async {
                setState(() => _empresaId = v);
                await _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _turnos.isEmpty
                    ? const Center(child: Text('No hay turnos en esta empresa'))
                    : ListView.builder(
                        itemCount: _turnos.length,
                        itemBuilder: (context, index) {
                          final turno = _turnos[index];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.schedule)),
                            title: Text(turno.nombre),
                            subtitle: Text(
                              '${turno.horarioLabel} · Tol. ${turno.toleranciaMinutos} min · '
                              '${diasSemanaTexto(turno.diasSemana)}'
                              '${turno.tieneHorarioAlmuerzo ? ' · Almuerzo ${turno.horaAlmuerzoInicio}-${turno.horaAlmuerzoFin}' : ''}',
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') _openForm(turno);
                                if (v == 'delete') _delete(turno);
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

class _TurnoFormDialog extends StatefulWidget {
  const _TurnoFormDialog({
    required this.empresaId,
    this.turno,
  });

  final int empresaId;
  final Turno? turno;

  @override
  State<_TurnoFormDialog> createState() => _TurnoFormDialogState();
}

class _TurnoFormDialogState extends State<_TurnoFormDialog> {
  late final TextEditingController _nombre;
  late final TextEditingController _tolerancia;
  late TimeOfDay _entrada;
  late TimeOfDay _salida;
  late TimeOfDay _almuerzoInicio;
  late TimeOfDay _almuerzoFin;
  late bool _definirAlmuerzo;
  late Set<int> _dias;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombre = TextEditingController(text: widget.turno?.nombre ?? '');
    _tolerancia = TextEditingController(
      text: '${widget.turno?.toleranciaMinutos ?? 15}',
    );
    _entrada = _parseTime(widget.turno?.horaEntrada ?? '08:00');
    _salida = _parseTime(widget.turno?.horaSalida ?? '17:00');
    _definirAlmuerzo = widget.turno?.tieneHorarioAlmuerzo ?? false;
    _almuerzoInicio = _parseTime(widget.turno?.horaAlmuerzoInicio ?? '12:00');
    _almuerzoFin = _parseTime(widget.turno?.horaAlmuerzoFin ?? '13:00');
    _dias = widget.turno != null
        ? widget.turno!.diasLista.toSet()
        : {1, 2, 3, 4, 5};
  }

  TimeOfDay _parseTime(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nombre.dispose();
    _tolerancia.dispose();
    super.dispose();
  }

  Future<void> _pickTime({
    required String tipo,
  }) async {
    final initial = switch (tipo) {
      'entrada' => _entrada,
      'salida' => _salida,
      'almuerzo_inicio' => _almuerzoInicio,
      _ => _almuerzoFin,
    };
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        switch (tipo) {
          case 'entrada':
            _entrada = picked;
          case 'salida':
            _salida = picked;
          case 'almuerzo_inicio':
            _almuerzoInicio = picked;
          case 'almuerzo_fin':
            _almuerzoFin = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final nombre = _nombre.text.trim();
    final tol = int.tryParse(_tolerancia.text.trim()) ?? 15;
    if (nombre.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    if (_dias.isEmpty) {
      setState(() => _error = 'Seleccione al menos un dia');
      return;
    }

    final dias = _dias.toList()..sort();
    final turno = Turno(
      id: widget.turno?.id,
      empresaId: widget.empresaId,
      nombre: nombre,
      horaEntrada: _formatTime(_entrada),
      horaSalida: _formatTime(_salida),
      toleranciaMinutos: tol,
      diasSemana: dias.join(','),
      horaAlmuerzoInicio: _definirAlmuerzo ? _formatTime(_almuerzoInicio) : null,
      horaAlmuerzoFin: _definirAlmuerzo ? _formatTime(_almuerzoFin) : null,
    );

    if (widget.turno == null) {
      await DbHelper.instance.insertTurno(turno);
    } else {
      await DbHelper.instance.updateTurno(turno);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.turno == null ? 'Nuevo turno' : 'Editar turno'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre del turno'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora entrada'),
              subtitle: Text(_formatTime(_entrada)),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () => _pickTime(tipo: 'entrada'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora salida'),
              subtitle: Text(_formatTime(_salida)),
              trailing: IconButton(
                icon: const Icon(Icons.access_time),
                onPressed: () => _pickTime(tipo: 'salida'),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Definir horario de almuerzo'),
              subtitle: const Text('Salidas en ese rango se registran como almuerzo sin radicado'),
              value: _definirAlmuerzo,
              onChanged: (v) => setState(() => _definirAlmuerzo = v),
            ),
            if (_definirAlmuerzo) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inicio almuerzo'),
                subtitle: Text(_formatTime(_almuerzoInicio)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () => _pickTime(tipo: 'almuerzo_inicio'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fin almuerzo'),
                subtitle: Text(_formatTime(_almuerzoFin)),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () => _pickTime(tipo: 'almuerzo_fin'),
                ),
              ),
            ],
            TextField(
              controller: _tolerancia,
              decoration: const InputDecoration(
                labelText: 'Tolerancia llegada (minutos)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            const Text('Dias de la semana'),
            Wrap(
              spacing: 4,
              children: diasSemanaLabels.entries.map((e) {
                final selected = _dias.contains(e.key);
                return FilterChip(
                  label: Text(e.value),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _dias.add(e.key);
                      } else {
                        _dias.remove(e.key);
                      }
                    });
                  },
                );
              }).toList(),
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
