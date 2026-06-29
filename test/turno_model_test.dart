import 'package:control_asistencia/models/registro.dart';
import 'package:control_asistencia/models/turno.dart';
import 'package:control_asistencia/services/marcacion_validator.dart';
import 'package:control_asistencia/services/turno_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Turno', () {
    test('detecta nocturno por horas que cruzan medianoche', () {
      const turno = Turno(
        nombre: 'Vigilancia',
        horaEntrada: '17:00',
        horaSalida: '10:00',
      );
      expect(turno.esNocturno, isTrue);
      expect(turno.horarioLabel, contains('dia sig'));
    });

    test('turno diurno no es nocturno', () {
      const turno = Turno(
        nombre: 'Oficina',
        horaEntrada: '08:00',
        horaSalida: '17:00',
      );
      expect(turno.esNocturno, isFalse);
    });

    test('flag turnoNocturno fuerza nocturno aunque horas parezcan diurnas', () {
      const turno = Turno(
        nombre: 'Especial',
        horaEntrada: '08:00',
        horaSalida: '17:00',
        turnoNocturno: true,
      );
      expect(turno.esNocturno, isTrue);
    });

    test('roundtrip toMap fromMap conserva turno_nocturno', () {
      const original = Turno(
        id: 3,
        nombre: 'Noche',
        horaEntrada: '22:00',
        horaSalida: '06:00',
        turnoNocturno: true,
        diasSemana: '1,2,3',
      );
      final restored = Turno.fromMap(original.toMap());
      expect(restored.turnoNocturno, isTrue);
      expect(restored.esNocturno, isTrue);
      expect(restored.diasLista, [1, 2, 3]);
    });
  });

  group('TurnoEvaluator seleccion', () {
    test('turnoParaFecha elige turno dentro del rango', () {
      const diurno = Turno(
        id: 1,
        nombre: 'Oficina',
        horaEntrada: '08:00',
        horaSalida: '17:00',
        diasSemana: '1,2,3,4,5,6,7',
      );
      const nocturno = Turno(
        id: 2,
        nombre: 'Vigilancia',
        horaEntrada: '17:00',
        horaSalida: '10:00',
        turnoNocturno: true,
        diasSemana: '1,2,3,4,5,6,7',
      );

      final aLas8 = TurnoEvaluator.turnoParaFecha(
        [diurno, nocturno],
        DateTime(2026, 6, 30, 8),
      );
      expect(aLas8?.id, 1);

      final aLas18 = TurnoEvaluator.turnoParaFecha(
        [diurno, nocturno],
        DateTime(2026, 6, 30, 18),
      );
      expect(aLas18?.id, 2);
    });

    test('turnoParaFecha respeta dias de la semana', () {
      const soloLunes = Turno(
        id: 1,
        nombre: 'Lunes',
        horaEntrada: '08:00',
        horaSalida: '17:00',
        diasSemana: '1',
      );
      final martes = DateTime(2026, 6, 30);
      expect(TurnoEvaluator.turnoParaFecha([soloLunes], martes), isNull);
    });

    test('finTurnoEsperado nocturno es dia siguiente', () {
      const turno = Turno(
        nombre: 'Vigilancia',
        horaEntrada: '17:00',
        horaSalida: '10:00',
        turnoNocturno: true,
      );
      final entrada = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 29, 17),
        fotoPath: 'f.jpg',
      );
      expect(
        TurnoEvaluator.finTurnoEsperado(entrada, turno),
        DateTime(2026, 6, 30, 10),
      );
    });

    test('evaluarMarcacion marca fuera de dias sin turno nocturno abierto', () {
      const soloSabado = Turno(
        nombre: 'Sabado',
        horaEntrada: '08:00',
        horaSalida: '12:00',
        diasSemana: '6',
        toleranciaMinutos: 0,
      );
      final obs = TurnoEvaluator.evaluarMarcacion(
        turno: soloSabado,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 30, 8),
        ultimoRegistro: null,
      );
      expect(obs, 'FUERA DE DIAS DE TURNO');
    });

    test('tolerancia evita llegada tarde dentro del margen', () {
      const turno = Turno(
        nombre: 'Oficina',
        horaEntrada: '08:00',
        horaSalida: '17:00',
        toleranciaMinutos: 15,
        diasSemana: '1,2,3,4,5,6,7',
      );
      expect(
        TurnoEvaluator.evaluarMarcacion(
          turno: turno,
          tipo: TipoMarcacion.entrada,
          fechaHora: DateTime(2026, 6, 30, 8, 10),
          ultimoRegistro: null,
        ),
        isNull,
      );
      expect(
        TurnoEvaluator.evaluarMarcacion(
          turno: turno,
          tipo: TipoMarcacion.entrada,
          fechaHora: DateTime(2026, 6, 30, 8, 16),
          ultimoRegistro: null,
        ),
        contains('LLEGADA TARDE'),
      );
    });

    test('turno nocturno con salida tarde del dia siguiente (ej 18:00)', () {
      const turno = Turno(
        id: 2,
        nombre: 'Vigilancia',
        horaEntrada: '17:00',
        horaSalida: '18:00',
        turnoNocturno: true,
        diasSemana: '1,2,3,4,5,6,7',
      );

      final fin = TurnoEvaluator.finTurnoEsperado(
        Registro(
          empresaId: 1,
          empleadoId: 1,
          tipo: TipoMarcacion.entrada,
          fechaHora: DateTime(2026, 6, 29, 17),
          fotoPath: 'f.jpg',
        ),
        turno,
      );
      expect(fin, DateTime(2026, 6, 30, 18));

      expect(
        TurnoEvaluator.turnoParaFecha(
          [turno],
          DateTime(2026, 6, 30, 8),
        ),
        turno,
      );
      expect(
        MarcacionValidator.requiereCierreSalidaPendiente(
          Registro(
            empresaId: 1,
            empleadoId: 1,
            tipo: TipoMarcacion.entrada,
            fechaHora: DateTime(2026, 6, 29, 17),
            fotoPath: 'f.jpg',
          ),
          ahora: DateTime(2026, 6, 30, 14),
          turno: turno,
        ),
        isFalse,
      );
    });
  });
}
