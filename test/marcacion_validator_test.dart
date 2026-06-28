import 'package:control_asistencia/models/registro.dart';
import 'package:control_asistencia/services/marcacion_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MarcacionValidator', () {
    test('sin historial solo permite entrada', () {
      expect(MarcacionValidator.tipoPermitido(null), TipoMarcacion.entrada);
      expect(
        MarcacionValidator.puedeMarcar(null, TipoMarcacion.entrada),
        isTrue,
      );
      expect(
        MarcacionValidator.puedeMarcar(null, TipoMarcacion.salida),
        isFalse,
      );
    });

    test('alterna entrada y salida', () {
      final entrada = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 1, 1, 8),
        fotoPath: 'foto.jpg',
      );

      expect(
        MarcacionValidator.tipoPermitido(entrada),
        TipoMarcacion.salida,
      );
      expect(
        MarcacionValidator.puedeMarcar(entrada, TipoMarcacion.salida),
        isTrue,
      );
      expect(
        MarcacionValidator.puedeMarcar(entrada, TipoMarcacion.entrada),
        isFalse,
      );
    });
  });
}
