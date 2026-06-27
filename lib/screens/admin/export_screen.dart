import 'package:flutter/material.dart';

import '../../database/db_helper.dart';
import '../../models/empresa.dart';
import '../../services/export_service.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  List<Empresa> _empresas = [];
  int? _empresaId;
  DateTime? _desde;
  DateTime? _hasta;
  bool _exporting = false;
  String? _lastFile;

  @override
  void initState() {
    super.initState();
    _loadEmpresas();
  }

  Future<void> _loadEmpresas() async {
    final empresas = await DbHelper.instance.getEmpresas();
    if (mounted) setState(() => _empresas = empresas);
  }

  Future<void> _pickDate({required bool desde}) async {
    final initial = desde ? (_desde ?? DateTime.now()) : (_hasta ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (desde) {
          _desde = DateTime(picked.year, picked.month, picked.day);
        } else {
          _hasta = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        }
      });
    }
  }

  Future<void> _export({bool share = false}) async {
    setState(() {
      _exporting = true;
      _lastFile = null;
    });

    try {
      final file = await ExportService.instance.exportCsv(
        empresaId: _empresaId,
        desde: _desde,
        hasta: _hasta,
      );
      if (share) {
        await ExportService.instance.shareFile(file);
      }
      if (mounted) {
        setState(() => _lastFile = file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(share ? 'Reporte compartido' : 'Reporte guardado')),
        );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Exportar reporte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int?>(
            value: _empresaId,
            decoration: const InputDecoration(
              labelText: 'Empresa',
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Desde'),
            subtitle: Text(_desde?.toString().split(' ').first ?? 'Sin filtro'),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _pickDate(desde: true),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hasta'),
            subtitle: Text(_hasta?.toString().split(' ').first ?? 'Sin filtro'),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () => _pickDate(desde: false),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _exporting ? null : () => _export(),
            icon: const Icon(Icons.save),
            label: const Text('Generar CSV'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _exporting ? null : () => _export(share: true),
            icon: const Icon(Icons.share),
            label: const Text('Generar y compartir'),
          ),
          if (_lastFile != null) ...[
            const SizedBox(height: 24),
            Text('Ultimo archivo:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(_lastFile!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
