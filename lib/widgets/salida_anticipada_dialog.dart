import 'package:flutter/material.dart';

import '../models/motivo_salida.dart';

class SalidaAnticipadaDialog extends StatefulWidget {
  const SalidaAnticipadaDialog({super.key});

  @override
  State<SalidaAnticipadaDialog> createState() => _SalidaAnticipadaDialogState();
}

class _SalidaAnticipadaDialogState extends State<SalidaAnticipadaDialog> {
  MotivoSalida _motivo = MotivoSalida.citaMedica;
  final _radicado = TextEditingController();
  final _nota = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _radicado.dispose();
    _nota.dispose();
    super.dispose();
  }

  void _confirmar() {
    final radicado = _radicado.text.trim();
    if (_motivo.requiereRadicado && radicado.isEmpty) {
      setState(() => _error = 'El radicado es obligatorio para este motivo');
      return;
    }
    final nota = _nota.text.trim();
    Navigator.pop(
      context,
      SalidaAnticipadaData(
        motivo: _motivo,
        radicado: _motivo.requiereRadicado ? radicado : null,
        nota: _motivo.permiteNotaLibre && nota.isNotEmpty ? nota : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Salida anticipada'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Indique el motivo de la salida antes del horario del turno.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<MotivoSalida>(
              initialValue: _motivo,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              items: MotivoSalida.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _motivo = v ?? MotivoSalida.citaMedica;
                _error = null;
              }),
            ),
            if (_motivo.requiereRadicado) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _radicado,
                decoration: const InputDecoration(
                  labelText: 'Numero de radicado',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
            if (_motivo.permiteNotaLibre) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nota,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                  hintText: 'Ej: salida personal, diligencia, etc.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
            if (_motivo == MotivoSalida.almuerzo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Almuerzo no requiere radicado.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirmar, child: const Text('Continuar')),
      ],
    );
  }
}
