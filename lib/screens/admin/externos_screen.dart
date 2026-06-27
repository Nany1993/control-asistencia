import 'package:flutter/material.dart';

import 'personas_admin_screen.dart';

class ExternosScreen extends StatelessWidget {
  const ExternosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PersonasAdminScreen(
      esExterno: true,
      titulo: 'Externos',
      etiquetaNuevo: 'Nuevo externo',
    );
  }
}
