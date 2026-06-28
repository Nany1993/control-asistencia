import '../models/registro.dart';

class MarcacionValidator {
  MarcacionValidator._();

  static bool _esMismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
