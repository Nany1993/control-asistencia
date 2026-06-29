import 'package:control_asistencia/models/registro.dart';
import 'package:control_asistencia/models/turno.dart';
import 'package:control_asistencia/services/marcacion_validator.dart';
import 'package:control_asistencia/services/turno_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Replica la guarda de _cerrarEntradaPendienteSiAplica (sin DB).
bool debeIntentarCierreAutomatico({
  required Registro? ultimoRegistro,
  required TipoMarcacion tipo,
  required DateTime ahora,
  Turno? turnoCierre,
}) {
  if (tipo != TipoMarcacion.entrada || ultimoRegistro == null) {
    return false;
  }
  return MarcacionValidator.requiereCierreSalidaPendiente(
    ultimoRegistro,
    ahora: ahora,
    turno: turnoCierre,
  );
}

Registro entrada({
  required DateTime fechaHora,
  int empleadoId = 1,
}) {
  return Registro(
    empresaId: 1,
    empleadoId: empleadoId,
    tipo: TipoMarcacion.entrada,
    fechaHora: fechaHora,
    fotoPath: 'foto.jpg',
    turnoId: 1,
  );
}

Registro salida({
  required DateTime fechaHora,
  int empleadoId = 1,
}) {
  return Registro(
    empresaId: 1,
    empleadoId: empleadoId,
    tipo: TipoMarcacion.salida,
    fechaHora: fechaHora,
    fotoPath: 'foto.jpg',
  );
}

void main() {
  group('Flujo guardar entrada (regresion v1.8.10)', () {
    test('primera entrada del dia sin historial no intenta cierre', () {
      expect(
        debeIntentarCierreAutomatico(
          ultimoRegistro: null,
          tipo: TipoMarcacion.entrada,
          ahora: DateTime(2026, 6, 30, 8),
        ),
        isFalse,
      );
      expect(
        MarcacionValidator.puedeMarcar(null, TipoMarcacion.entrada),
        isTrue,
      );
    });

    test('entrada mismo dia con entrada abierta no intenta cierre al reingresar', () {
      final ultimo = entrada(fechaHora: DateTime(2026, 6, 30, 8));
      expect(
        debeIntentarCierreAutomatico(
          ultimoRegistro: ultimo,
          tipo: TipoMarcacion.entrada,
          ahora: DateTime(2026, 6, 30, 8, 5),
          turnoCierre: const Turno(
            nombre: 'Oficina',
            horaEntrada: '08:00',
            horaSalida: '17:00',
          ),
        ),
        isFalse,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          ultimo,
          TipoMarcacion.entrada,
          ahora: DateTime(2026, 6, 30, 8, 5),
        ),
        isFalse,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          ultimo,
          TipoMarcacion.salida,
          ahora: DateTime(2026, 6, 30, 12),
        ),
        isTrue,
      );
    });

    test('entrada dia anterior diurno intenta cierre al marcar entrada hoy', () {
      const turno = Turno(
        nombre: 'Oficina',
        horaEntrada: '08:00',
        horaSalida: '17:00',
      );
      final ultimo = entrada(fechaHora: DateTime(2026, 6, 29, 8));
      final hoy = DateTime(2026, 6, 30, 8);

      expect(
        debeIntentarCierreAutomatico(
          ultimoRegistro: ultimo,
          tipo: TipoMarcacion.entrada,
          ahora: hoy,
          turnoCierre: turno,
        ),
        isTrue,
      );
      expect(
        MarcacionValidator.fechaCierreSalidaPendiente(ultimo, turno: turno),
        DateTime(2026, 6, 29, 17),
      );
      expect(
        MarcacionValidator.puedeMarcar(ultimo, TipoMarcacion.entrada, ahora: hoy),
        isTrue,
      );
    });

    test('nocturno en turno permite salida sin cierre automatico', () {
      const turno = Turno(
        nombre: 'Vigilancia',
        horaEntrada: '17:00',
        horaSalida: '10:00',
        turnoNocturno: true,
      );
      final ultimo = entrada(fechaHora: DateTime(2026, 6, 29, 17));
      final mananaTemprano = DateTime(2026, 6, 30, 8);

      expect(
        debeIntentarCierreAutomatico(
          ultimoRegistro: ultimo,
          tipo: TipoMarcacion.entrada,
          ahora: mananaTemprano,
          turnoCierre: turno,
        ),
        isFalse,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          ultimo,
          TipoMarcacion.salida,
          ahora: mananaTemprano,
          turno: turno,
        ),
        isTrue,
      );
    });
  });

  group('Secuencias completas de marcacion', () {
    test('dia laboral tipico: entrada -> salida -> entrada', () {
      var ultimo = entrada(fechaHora: DateTime(2026, 6, 30, 8));
      expect(
        MarcacionValidator.tipoPermitido(ultimo, ahora: DateTime(2026, 6, 30, 12)),
        TipoMarcacion.salida,
      );

      ultimo = salida(fechaHora: DateTime(2026, 6, 30, 17));
      expect(
        MarcacionValidator.tipoPermitido(ultimo, ahora: DateTime(2026, 6, 30, 18)),
        TipoMarcacion.entrada,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          ultimo,
          TipoMarcacion.entrada,
          ahora: DateTime(2026, 6, 30, 18),
        ),
        isTrue,
      );
    });

    test('despues de salida ayer permite entrada hoy sin cierre', () {
      final ultimo = salida(fechaHora: DateTime(2026, 6, 29, 17));
      expect(
        MarcacionValidator.requiereCierreSalidaPendiente(
          ultimo,
          ahora: DateTime(2026, 6, 30, 8),
        ),
        isFalse,
      );
      expect(
        MarcacionValidator.puedeMarcar(
          ultimo,
          TipoMarcacion.entrada,
          ahora: DateTime(2026, 6, 30, 8),
        ),
        isTrue,
      );
    });

    test('sin turno entrada abierta ayer solo permite nueva entrada hoy', () {
      final ultimo = entrada(fechaHora: DateTime(2026, 6, 29, 8));
      final hoy = DateTime(2026, 6, 30, 8);

      expect(
        MarcacionValidator.tipoPermitido(ultimo, ahora: hoy),
        TipoMarcacion.entrada,
      );
      expect(
        MarcacionValidator.puedeMarcar(ultimo, TipoMarcacion.salida, ahora: hoy),
        isFalse,
      );
    });
  });

  group('Limites horarios nocturnos', () {
    const turno = Turno(
      nombre: 'Vigilancia',
      horaEntrada: '17:00',
      horaSalida: '10:00',
      turnoNocturno: true,
    );

    test('exactamente a la hora de salida el turno sigue abierto', () {
      final ultimo = entrada(fechaHora: DateTime(2026, 6, 29, 17));
      final fin = DateTime(2026, 6, 30, 10);

      expect(
        TurnoEvaluator.turnoNocturnoAbierto(
          entradaAbierta: ultimo,
          turno: turno,
          ahora: fin,
        ),
        isTrue,
      );
      expect(
        MarcacionValidator.requiereCierreSalidaPendiente(
          ultimo,
          ahora: fin,
          turno: turno,
        ),
        isFalse,
      );
    });

    test('un minuto despues del fin requiere cierre', () {
      final ultimo = entrada(fechaHora: DateTime(2026, 6, 29, 17));
      final despues = DateTime(2026, 6, 30, 10, 1);

      expect(
        MarcacionValidator.requiereCierreSalidaPendiente(
          ultimo,
          ahora: despues,
          turno: turno,
        ),
        isTrue,
      );
    });
  });

  group('Mensajes de bloqueo', () {
    test('bloquea salida si ultima fue salida', () {
      final ultimo = salida(fechaHora: DateTime(2026, 6, 30, 12));
      final msg = MarcacionValidator.mensajeBloqueo(
        ultimo,
        TipoMarcacion.salida,
        ahora: DateTime(2026, 6, 30, 13),
      );
      expect(msg, contains('entrada'));
    });

    test('bloquea entrada si ya hay entrada abierta hoy', () {
      final ultimo = entrada(fechaHora: DateTime(2026, 6, 30, 8));
      final msg = MarcacionValidator.mensajeBloqueo(
        ultimo,
        TipoMarcacion.entrada,
        ahora: DateTime(2026, 6, 30, 9),
      );
      expect(msg, contains('salida'));
    });
  });
}
