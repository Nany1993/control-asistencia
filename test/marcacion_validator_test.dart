import 'package:control_asistencia/models/registro.dart';
import 'package:control_asistencia/models/turno.dart';
import 'package:control_asistencia/services/marcacion_validator.dart';
import 'package:control_asistencia/services/turno_evaluator.dart';
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

    test('entrada de dia anterior permite nueva entrada hoy sin turno nocturno', () {
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
        MarcacionValidator.requiereCierreSalidaPendiente(entradaAyer, ahora: hoy),
        isTrue,
      );
    });

    test('fecha cierre usa hora de salida del turno diurno', () {
      final entrada = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 26, 8),
        fotoPath: 'foto.jpg',
      );
      const turno = Turno(
        nombre: 'Oficina',
        horaEntrada: '08:00',
        horaSalida: '17:00',
      );

      final cierre = MarcacionValidator.fechaCierreSalidaPendiente(
        entrada,
        turno: turno,
      );

      expect(cierre, DateTime(2026, 6, 26, 17, 0));
    });

    test('turno nocturno permite salida al dia siguiente antes de la hora fin', () {
      const turno = Turno(
        nombre: 'Vigilancia',
        horaEntrada: '17:00',
        horaSalida: '10:00',
        turnoNocturno: true,
        diasSemana: '1,2,3,4,5,6,7',
      );
      final entrada = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 29, 17),
        fotoPath: 'foto.jpg',
        turnoId: 1,
      );
      final martesManana = DateTime(2026, 6, 30, 8);

      expect(
        MarcacionValidator.tipoPermitido(
          entrada,
          ahora: martesManana,
          turno: turno,
        ),
        TipoMarcacion.salida,
      );
      expect(
        MarcacionValidator.requiereCierreSalidaPendiente(
          entrada,
          ahora: martesManana,
          turno: turno,
        ),
        isFalse,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          entrada,
          TipoMarcacion.salida,
          ahora: martesManana,
          turno: turno,
        ),
        isTrue,
      );
    });

    test('turno nocturno cierra automatico despues de la hora de salida', () {
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
        fotoPath: 'foto.jpg',
      );
      final despuesDelTurno = DateTime(2026, 6, 30, 11);

      expect(
        MarcacionValidator.requiereCierreSalidaPendiente(
          entrada,
          ahora: despuesDelTurno,
          turno: turno,
        ),
        isTrue,
      );
      expect(
        MarcacionValidator.fechaCierreSalidaPendiente(entrada, turno: turno),
        DateTime(2026, 6, 30, 10, 0),
      );
      expect(
        MarcacionValidator.tipoPermitido(
          entrada,
          ahora: despuesDelTurno,
          turno: turno,
        ),
        TipoMarcacion.entrada,
      );
    });
  });

  group('TurnoEvaluator', () {
    test('retraso solo en la primera entrada del dia', () {
      const turno = Turno(
        nombre: 'Oficina',
        horaEntrada: '08:00',
        horaSalida: '17:00',
        toleranciaMinutos: 0,
        diasSemana: '1,2,3,4,5,6,7',
      );
      final salidaAlmuerzo = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.salida,
        fechaHora: DateTime(2026, 6, 27, 12),
        fotoPath: 'foto.jpg',
      );
      final reingreso = DateTime(2026, 6, 27, 13, 30);

      expect(
        TurnoEvaluator.evaluarMarcacion(
          turno: turno,
          tipo: TipoMarcacion.entrada,
          fechaHora: reingreso,
          ultimoRegistro: salidaAlmuerzo,
        ),
        isNull,
      );
    });

    test('marca llegada tarde en la primera entrada del dia', () {
      const turno = Turno(
        nombre: 'Oficina',
        horaEntrada: '08:00',
        horaSalida: '17:00',
        toleranciaMinutos: 0,
        diasSemana: '1,2,3,4,5,6,7',
      );

      final obs = TurnoEvaluator.evaluarMarcacion(
        turno: turno,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 27, 8, 20),
        ultimoRegistro: null,
      );

      expect(obs, contains('LLEGADA TARDE'));
    });

    test('detecta salida anticipada en turno nocturno', () {
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
        fotoPath: 'foto.jpg',
      );

      expect(
        TurnoEvaluator.esSalidaAnticipada(
          turno: turno,
          fechaHora: DateTime(2026, 6, 30, 9),
          entradaAbierta: entrada,
        ),
        isTrue,
      );
      expect(
        TurnoEvaluator.esSalidaAnticipada(
          turno: turno,
          fechaHora: DateTime(2026, 6, 30, 10),
          entradaAbierta: entrada,
        ),
        isFalse,
      );
    });

    test('turnoParaMarcacion mantiene turno nocturno abierto', () {
      const turno = Turno(
        id: 1,
        nombre: 'Vigilancia',
        horaEntrada: '17:00',
        horaSalida: '10:00',
        turnoNocturno: true,
        diasSemana: '1,2,3,4,5,6,7',
      );
      final entrada = Registro(
        empresaId: 1,
        empleadoId: 1,
        tipo: TipoMarcacion.entrada,
        fechaHora: DateTime(2026, 6, 29, 17),
        fotoPath: 'foto.jpg',
        turnoId: 1,
      );

      final activo = TurnoEvaluator.turnoParaMarcacion(
        [turno],
        entrada,
        DateTime(2026, 6, 30, 8),
        turnoEntradaPendiente: turno,
      );

      expect(activo?.id, 1);
    });
  });
}
