import 'package:flutter/material.dart';

import '../widgets/info_text.dart';
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
          title: const InfoText('Control Asistencia'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.badge), text: 'TURNO'),
              Tab(icon: Icon(Icons.school_outlined), text: 'CAPACITACION'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: 'ADMINISTRACION',
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
