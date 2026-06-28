import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../database/backup_restore_exception.dart';
import '../../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _working = false;
  String? _lastBackupPath;

  Future<void> _createBackup({required bool share}) async {
    setState(() {
      _working = true;
      _lastBackupPath = null;
    });

    try {
      final file = await BackupService.instance.createBackup();
      if (share) {
        await BackupService.instance.shareBackup(file);
      }
      if (mounted) {
        setState(() => _lastBackupPath = file.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              share
                  ? 'Respaldo listo para compartir o guardar'
                  : 'Respaldo generado correctamente',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear respaldo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar respaldo'),
        content: const Text(
          'Esta accion reemplazara todos los datos actuales de la app '
          '(base de datos, fotos y reportes) por los del archivo ZIP seleccionado.\n\n'
          '¿Desea continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _working = true);
    try {
      await BackupService.instance.restoreBackup(
        File(result.files.single.path!),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Respaldo restaurado. Los datos ya estan disponibles en la app.',
            ),
          ),
        );
      }
    } on BackupRestoreException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al restaurar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo de datos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Que incluye el respaldo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Base de datos (empresas, empleados, registros, capacitaciones)'),
                  Text('• Fotos de asistencia laboral'),
                  Text('• Fotos de capacitaciones'),
                  Text('• Reportes exportados (CSV/PDF)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Guarde el archivo .zip en Drive, correo o una PC. '
            'Luego puede restaurarlo en este u otro dispositivo con la app instalada.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _working ? null : () => _createBackup(share: false),
            icon: _working
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Generar respaldo'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _working ? null : () => _createBackup(share: true),
            icon: const Icon(Icons.share),
            label: const Text('Generar y compartir respaldo'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Restaurar desde archivo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Seleccione un .zip generado previamente por esta app. '
            'Reemplazara los datos actuales del telefono.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _working ? null : _restoreBackup,
            icon: const Icon(Icons.restore),
            label: const Text('Seleccionar ZIP y restaurar'),
          ),
          if (_lastBackupPath != null) ...[
            const SizedBox(height: 24),
            Text(
              'Ultimo respaldo:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              _lastBackupPath!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
