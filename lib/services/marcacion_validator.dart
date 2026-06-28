import '../models/registro.dart';
import '../models/turno.dart';
import 'turno_evaluator.dart';

class MarcacionValidator {
  MarcacionValidator._();

  static bool _esMismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static TipoMarcacion tipoPermitido(
    Registro? ultimo, {
    DateTime? ahora,
    Turno? turno,
  }) {
    final ref = ahora ?? DateTime.now();
    if (ultimo == null) return TipoMarcacion.entrada;

    if (ultimo.tipo == TipoMarcacion.entrada) {
      if (turno != null &&
          TurnoEvaluator.turnoNocturnoAbierto(
            entradaAbierta: ultimo,
            turno: turno,
            ahora: ref,
          )) {
        return TipoMarcacion.salida;
      }
      if (!_esMismoDia(ultimo.fechaHora, ref)) {
        return TipoMarcacion.entrada;
      }
      return TipoMarcacion.salida;
    }

    return TipoMarcacion.entrada;
  }

  static bool puedeMarcar(
    Registro? ultimo,
    TipoMarcacion tipo, {
    DateTime? ahora,
    Turno? turno,
  }) {
    return tipoPermitido(ultimo, ahora: ahora, turno: turno) == tipo;
  }

  /// Entrada sin salida que debe cerrarse antes de una nueva entrada.
  static bool requiereCierreSalidaPendiente(
    Registro? ultimo, {
    DateTime? ahora,
    Turno? turno,
  }) {
    if (ultimo == null) return false;
    if (ultimo.tipo != TipoMarcacion.entrada) return false;

    final ref = ahora ?? DateTime.now();
    if (turno != null && TurnoEvaluator.esNocturno(turno)) {
      return ref.isAfter(TurnoEvaluator.finTurnoEsperado(ultimo, turno));
    }
    return !_esMismoDia(ultimo.fechaHora, ref);
  }

  /// Hora de cierre automatico: fin del turno o 23:59 del dia de la entrada.
  static DateTime fechaCierreSalidaPendiente(
    Registro entradaAbierta, {
    Turno? turno,
  }) {
    if (turno != null) {
      return TurnoEvaluator.finTurnoEsperado(entradaAbierta, turno);
    }
    final dia = DateTime(
      entradaAbierta.fechaHora.year,
      entradaAbierta.fechaHora.month,
      entradaAbierta.fechaHora.day,
    );
    return DateTime(dia.year, dia.month, dia.day, 23, 59, 59);
  }

  static const observacionCierreAutomatico = 'NO REGISTRO SALIDA';

  static String mensajeBloqueo(
    Registro? ultimo,
    TipoMarcacion tipo, {
    DateTime? ahora,
    Turno? turno,
  }) {
    final permitido = tipoPermitido(ultimo, ahora: ahora, turno: turno);
    if (ultimo == null) {
      return 'Debe registrar primero una entrada.';
    }
    if (tipo == TipoMarcacion.salida && permitido == TipoMarcacion.entrada) {
      if (ultimo.tipo == TipoMarcacion.entrada &&
          !_esMismoDia(ultimo.fechaHora, ahora ?? DateTime.now()) &&
          (turno == null || !TurnoEvaluator.esNocturno(turno))) {
        return 'La ultima entrada es de otro dia. Registre la entrada de hoy.';
      }
      return 'Ya registro salida. Debe marcar entrada antes de salir otra vez.';
    }
    if (tipo == TipoMarcacion.entrada && permitido == TipoMarcacion.salida) {
      return 'Ya registro entrada. Debe marcar salida antes de entrar otra vez.';
    }
    return 'Marcacion no permitida. Siguiente: ${permitido.label}.';
  }
}
