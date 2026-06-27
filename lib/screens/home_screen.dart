import 'package:flutter/material.dart';

import 'asistencia/asistencia_screen.dart';
import 'capacitacion/capacitacion_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Control Asistencia'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.badge), text: 'Turno'),
              Tab(icon: Icon(Icons.school_outlined), text: 'Capacitacion'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'Administracion',
              onPressed: () => Navigator.of(context).pushNamed('/admin-pin'),
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            AsistenciaScreen(),
            CapacitacionScreen(),
          ],
        ),
      ),
    );
  }
}
