import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final _actual = TextEditingController();
  final _nuevo = TextEditingController();
  final _confirmar = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _actual.dispose();
    _nuevo.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    final actual = _actual.text.trim();
    final nuevo = _nuevo.text.trim();
    final confirmar = _confirmar.text.trim();

    if (nuevo.length < 4) {
      setState(() => _error = 'El nuevo PIN debe tener al menos 4 digitos');
      return;
    }
    if (nuevo != confirmar) {
      setState(() => _error = 'La confirmacion no coincide');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await AuthService.instance.verifyPin(actual);
    if (!ok) {
      setState(() {
        _loading = false;
        _error = 'PIN actual incorrecto';
      });
      return;
    }

    await AuthService.instance.changePin(nuevo);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN actualizado')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modificar PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ingrese el PIN actual y el nuevo PIN de administrador.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _actual,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN actual'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nuevo,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN nuevo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmar,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirmar PIN nuevo'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _changePin,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
