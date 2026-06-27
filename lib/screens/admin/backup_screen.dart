import 'package:flutter/material.dart';

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
            'Asi no pierde la informacion si cambia de dispositivo o desinstala la app.',
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
