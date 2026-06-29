import 'package:control_asistencia/models/registro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Registro', () {
    test('roundtrip con nota_admin', () {
      final original = Registro(
        id: 5,
        empresaId: 1,
        empleadoId: 2,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 30, 8),
        fotoPath: 'foto.jpg',
        observacion: 'LLEGADA TARDE (5 MIN DESPUES DE TOLERANCIA)',
        notaAdmin: 'Turno correcto vigilancia nocturna',
        empresaNombre: 'Empresa Test',
        empleadoNombre: 'Juan Perez',
        empleadoCargo: 'Vigilante',
        empleadoTipoDocumento: 'CC',
        empleadoNumeroDocumento: '123',
      );

      final map = original.toMap();
      expect(map['nota_admin'], 'TURNO CORRECTO VIGILANCIA NOCTURNA');
      expect(map['observacion'], contains('LLEGADA TARDE'));

      final restored = Registro.fromMap(map);
      expect(restored.notaAdmin, 'TURNO CORRECTO VIGILANCIA NOCTURNA');
      expect(restored.observacion, contains('LLEGADA TARDE'));
      expect(restored.tieneNotaAdmin, isTrue);
    });

    test('nota_admin vacia no cuenta como tiene nota', () {
      final reg = Registro.fromMap({
        'id': 1,
        'empresa_id': 1,
        'empleado_id': 1,
        'tipo': 'entrada',
        'fecha_hora': '2026-06-30T08:00:00.000',
        'foto_path': 'f.jpg',
        'nota_admin': '',
        'empresa_nombre': '',
        'empleado_cargo': '',
        'empleado_nombre': '',
        'empleado_tipo_documento': '',
        'empleado_numero_documento': '',
        'empleado_es_externo': 0,
      });
      expect(reg.tieneNotaAdmin, isFalse);
      expect(reg.notaAdmin, isNull);
    });

    test('map sin nota_admin usa vacio', () {
      final reg = Registro.fromMap({
        'id': 1,
        'empresa_id': 1,
        'empleado_id': 1,
        'tipo': 'salida',
        'fecha_hora': '2026-06-30T17:00:00.000',
        'foto_path': 'f.jpg',
        'empresa_nombre': '',
        'empleado_cargo': '',
        'empleado_nombre': '',
        'empleado_tipo_documento': '',
        'empleado_numero_documento': '',
        'empleado_es_externo': 0,
      });
      expect(reg.notaAdmin, isNull);
    });
  });
}
