import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/admin/pin_screen.dart';
import 'screens/asistencia/asistencia_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.ensureDefaultPin();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ControlAsistenciaApp());
}

class ControlAsistenciaApp extends StatelessWidget {
  const ControlAsistenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control Asistencia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const AsistenciaScreen(),
        '/admin-pin': (_) => const PinScreen(),
      },
    );
  }
}
