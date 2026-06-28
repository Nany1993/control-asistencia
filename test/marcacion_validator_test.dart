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

    test('alterna entrada y salida el mismo dia', () {
      final cuando = DateTime(2026, 1, 1, 12);
      final entrada = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 1, 1, 8),
        fotoPath: 'foto.jpg',
      );

      expect(
        MarcacionValidator.tipoPermitido(entrada, ahora: cuando),
        TipoMarcacion.salida,
      );
      expect(
        MarcacionValidator.puedeMarcar(entrada, TipoMarcacion.salida, ahora: cuando),
        isTrue,
      );
      expect(
        MarcacionValidator.puedeMarcar(entrada, TipoMarcacion.entrada, ahora: cuando),
        isFalse,
      );
    });

    test('entrada de dia anterior permite nueva entrada hoy', () {
      final entradaAyer = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 26, 17),
        fotoPath: 'foto.jpg',
      );
      final hoy = DateTime(2026, 6, 27, 8);

      expect(
        MarcacionValidator.tipoPermitido(entradaAyer, ahora: hoy),
        TipoMarcacion.entrada,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          entradaAyer,
          TipoMarcacion.entrada,
          ahora: hoy,
        ),
        isTrue,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          entradaAyer,
          TipoMarcacion.salida,
          ahora: hoy,
        ),
        isFalse,
      );
    });
  });
}
