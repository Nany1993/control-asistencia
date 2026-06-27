import 'package:flutter/material.dart';

import 'personas_admin_screen.dart';

class EmpleadosScreen extends StatelessWidget {
  const EmpleadosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PersonasAdminScreen(
      esExterno: false,
      titulo: 'Empleados (internos)',
      etiquetaNuevo: 'Nuevo',
    );
  }
}
