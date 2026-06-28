import 'package:flutter/material.dart';

import 'asistencia_cap_screen.dart';
import 'backup_screen.dart';
import 'capacitaciones_screen.dart';
import 'config_screen.dart';
import 'empleados_screen.dart';
import 'empresas_screen.dart';
import 'export_screen.dart';
import 'externos_screen.dart';
import 'registros_screen.dart';
import 'turnos_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administracion'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminTile(
            icon: Icons.business,
            title: 'Empresas',
            subtitle: 'Crear, editar y eliminar empresas',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmpresasScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.schedule,
            title: 'Turnos',
            subtitle: 'Horarios compartidos entre todas las empresas',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TurnosScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.people,
            title: 'Empleados (internos)',
            subtitle: 'Personal interno por empresa',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmpleadosScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.person_outline,
            title: 'Externos',
            subtitle: 'Visitantes y contratistas guardados',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExternosScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.school,
            title: 'Capacitaciones',
            subtitle: 'Crear y cerrar sesiones de formacion',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CapacitacionesScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.fact_check,
            title: 'Asistencia capacitaciones',
            subtitle: 'Consultar asistentes y fotos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AsistenciaCapScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.history,
            title: 'Registros',
            subtitle: 'Ver marcaciones guardadas',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegistrosScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.file_download,
            title: 'Exportar',
            subtitle: 'Generar CSV y compartir reporte',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExportScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.backup,
            title: 'Respaldo de datos',
            subtitle: 'Descargar copia de base de datos y fotos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
          _AdminTile(
            icon: Icons.lock_reset,
            title: 'Modificar PIN',
            subtitle: 'Cambiar PIN de administrador',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfigScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
