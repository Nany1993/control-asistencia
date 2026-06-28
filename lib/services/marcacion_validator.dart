import '../models/registro.dart';
import '../models/turno.dart';

class MarcacionValidator {
  MarcacionValidator._();

  static bool _esMismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _horaEnDia(DateTime fecha, String hhmm) {
    final partes = hhmm.split(':');
    final h = int.parse(partes[0]);
    final m = int.parse(partes[1]);
    return DateTime(fecha.year, fecha.month, fecha.day, h, m);
  }

  static TipoMarcacion tipoPermitido(Registro? ultimo, {DateTime? ahora}) {
    final ref = ahora ?? DateTime.now();
    if (ultimo == null) return TipoMarcacion.entrada;

    if (ultimo.tipo == TipoMarcacion.entrada &&
        !_esMismoDia(ultimo.fechaHora, ref)) {
      return TipoMarcacion.entrada;
    }

    return ultimo.tipo == TipoMarcacion.entrada
        ? TipoMarcacion.salida
        : TipoMarcacion.entrada;
  }

  static bool puedeMarcar(
    Registro? ultimo,
    TipoMarcacion tipo, {
    DateTime? ahora,
  }) {
    return tipoPermitido(ultimo, ahora: ahora) == tipo;
  }

  /// Entrada de un dia anterior sin salida registrada.
  static bool requiereCierreSalidaPendiente(
    Registro? ultimo, {
    DateTime? ahora,
  }) {
    if (ultimo == null) return false;
    if (ultimo.tipo != TipoMarcacion.entrada) return false;
    return !_esMismoDia(ultimo.fechaHora, ahora ?? DateTime.now());
  }

  /// Hora de cierre automatico: fin del turno del dia de la entrada o 23:59.
  static DateTime fechaCierreSalidaPendiente(
    Registro entradaAbierta, {
    Turno? turno,
  }) {
    final dia = DateTime(
      entradaAbierta.fechaHora.year,
      entradaAbierta.fechaHora.month,
      entradaAbierta.fechaHora.day,
    );
    if (turno != null) {
      return _horaEnDia(dia, turno.horaSalida);
    }
    return DateTime(dia.year, dia.month, dia.day, 23, 59, 59);
  }

  static const observacionCierreAutomatico = 'No registro salida';

  static String mensajeBloqueo(
    Registro? ultimo,
    TipoMarcacion tipo, {
    DateTime? ahora,
  }) {
    final permitido = tipoPermitido(ultimo, ahora: ahora);
    if (ultimo == null) {
      return 'Debe registrar primero una entrada.';
    }
    if (tipo == TipoMarcacion.salida && permitido == TipoMarcacion.entrada) {
      if (ultimo.tipo == TipoMarcacion.entrada &&
          !_esMismoDia(ultimo.fechaHora, ahora ?? DateTime.now())) {
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
