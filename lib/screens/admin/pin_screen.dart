import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'admin_home_screen.dart';
import 'config_screen.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _firstTime = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final configured = await AuthService.instance.isPinConfigured();
    if (mounted) {
      setState(() => _firstTime = !configured);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _controller.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'El PIN debe tener al menos 4 digitos');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final ok = await AuthService.instance.verifyPin(pin);
    if (!mounted) return;

    if (ok) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
      );
    } else {
      setState(() {
        _loading = false;
        _error = 'PIN incorrecto';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acceso administrador')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_firstTime)
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'PIN inicial: ${AuthService.defaultPin}. Cambielo en Configuracion.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: InputDecoration(
                labelText: 'PIN',
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ingresar'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loading
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ConfigScreen()),
                      ),
              icon: const Icon(Icons.lock_reset),
              label: const Text('Modificar PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
