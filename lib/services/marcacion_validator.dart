import '../models/registro.dart';

class MarcacionValidator {
  MarcacionValidator._();

  static TipoMarcacion tipoPermitido(Registro? ultimo) {
    if (ultimo == null) return TipoMarcacion.entrada;
    return ultimo.tipo == TipoMarcacion.entrada
        ? TipoMarcacion.salida
        : TipoMarcacion.entrada;
  }

  static bool puedeMarcar(Registro? ultimo, TipoMarcacion tipo) {
    return tipoPermitido(ultimo) == tipo;
  }

  static String mensajeBloqueo(Registro? ultimo, TipoMarcacion tipo) {
    final permitido = tipoPermitido(ultimo);
    if (ultimo == null) {
      return 'Debe registrar primero una entrada.';
    }
    if (tipo == TipoMarcacion.salida && permitido == TipoMarcacion.entrada) {
      return 'Ya registro salida. Debe marcar entrada antes de salir otra vez.';
    }
    if (tipo == TipoMarcacion.entrada && permitido == TipoMarcacion.salida) {
      return 'Ya registro entrada. Debe marcar salida antes de entrar otra vez.';
    }
    return 'Marcacion no permitida. Siguiente: ${permitido.label}.';
  }
}
