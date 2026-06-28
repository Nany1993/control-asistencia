import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../database/db_helper.dart';
import '../../models/asistencia_capacitacion.dart';
import '../../models/capacitacion.dart';

class AsistenciaCapScreen extends StatefulWidget {
  const AsistenciaCapScreen({super.key});

  @override
  State<AsistenciaCapScreen> createState() => _AsistenciaCapScreenState();
}

class _AsistenciaCapScreenState extends State<AsistenciaCapScreen> {
  List<Capacitacion> _capacitaciones = [];
  List<AsistenciaCapacitacion> _asistencias = [];
  int? _capacitacionId;
  bool _loading = true;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final caps = await DbHelper.instance.getCapacitaciones();
    if (mounted) {
      setState(() => _capacitaciones = caps);
      await _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DbHelper.instance.getAsistenciasCapacitacion(
      capacitacionId: _capacitacionId,
    );
    if (mounted) {
      setState(() {
        _asistencias = data;
        _loading = false;
      });
    }
  }

  void _verFoto(AsistenciaCapacitacion a) {
    final file = File(a.fotoPath);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file.existsSync())
              Image.file(file, fit: BoxFit.contain)
            else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Foto no encontrada'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Asistencia capacitaciones')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<int?>(
              initialValue: _capacitacionId,
              decoration: const InputDecoration(
                labelText: 'Capacitacion',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                ..._capacitaciones.map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.nombre),
                  ),
                ),
              ],
              onChanged: (v) async {
                setState(() => _capacitacionId = v);
                await _load();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _asistencias.isEmpty
                    ? const Center(child: Text('Sin asistencias registradas'))
                    : ListView.builder(
                        itemCount: _asistencias.length,
                        itemBuilder: (context, index) {
                          final a = _asistencias[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(Icons.person, color: Colors.blue.shade800),
                            ),
                            title: Text(
                              a.empleadoCargo != null && a.empleadoCargo!.isNotEmpty
                                  ? '${a.empleadoNombre ?? 'Persona'} · ${a.empleadoCargo}'
                                  : (a.empleadoNombre ?? 'Persona'),
                            ),
                            subtitle: Text(
                              [
                                a.capacitacionNombre ?? '',
                                a.documentoLabel,
                                a.tipoPersonaLabel,
                                a.empresaNombre ?? '',
                                _dateFormat.format(a.fechaHora),
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                            trailing: const Icon(Icons.photo_camera),
                            onTap: () => _verFoto(a),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
