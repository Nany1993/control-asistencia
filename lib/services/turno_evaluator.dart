import '../models/motivo_salida.dart';
import '../models/registro.dart';
import '../models/turno.dart';

class TurnoEvaluator {
  TurnoEvaluator._();

  static bool aplicaEnFecha(Turno turno, DateTime fechaHora) {
    final dias = turno.diasLista;
    if (dias.isEmpty) return true;
    return dias.contains(fechaHora.weekday);
  }

  static bool aplicaHoy(Turno turno) => aplicaEnFecha(turno, DateTime.now());

  /// Turno asignado que corresponde al dia de [fechaHora].
  static Turno? turnoParaFecha(List<Turno> turnos, DateTime fechaHora) {
    for (final turno in turnos) {
      if (aplicaEnFecha(turno, fechaHora)) return turno;
    }
    return null;
  }

  static DateTime _horaEnDia(DateTime fecha, String hhmm) {
    final partes = hhmm.split(':');
    final h = int.parse(partes[0]);
    final m = int.parse(partes[1]);
    return DateTime(fecha.year, fecha.month, fecha.day, h, m);
  }

  static bool esSalidaAnticipada({
    required Turno turno,
    required DateTime fechaHora,
  }) {
    if (!aplicaHoy(turno)) return false;
    final horaSalida = _horaEnDia(fechaHora, turno.horaSalida);
    return fechaHora.isBefore(horaSalida);
  }

  static bool esHorarioAlmuerzo({
    required Turno turno,
    required DateTime fechaHora,
  }) {
    if (!turno.tieneHorarioAlmuerzo) return false;
    final inicio = _horaEnDia(fechaHora, turno.horaAlmuerzoInicio!);
    final fin = _horaEnDia(fechaHora, turno.horaAlmuerzoFin!);
    return !fechaHora.isBefore(inicio) && fechaHora.isBefore(fin);
  }

  static bool esPrimeraEntradaDelDia({
    required Registro? ultimoRegistro,
    required DateTime fechaHora,
  }) {
    if (ultimoRegistro == null) return true;
    final hoy = DateTime(fechaHora.year, fechaHora.month, fechaHora.day);
    final diaUltimo = DateTime(
      ultimoRegistro.fechaHora.year,
      ultimoRegistro.fechaHora.month,
      ultimoRegistro.fechaHora.day,
    );
    if (diaUltimo.isBefore(hoy)) return true;
    return ultimoRegistro.tipo != TipoMarcacion.salida;
  }

  static bool _esMismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String? evaluarRetornoAlmuerzo({
    required Turno turno,
    required Registro? ultimoRegistro,
    required DateTime fechaHora,
  }) {
    if (ultimoRegistro == null) return null;
    if (ultimoRegistro.tipo != TipoMarcacion.salida) return null;
    if (ultimoRegistro.motivoSalida != MotivoSalida.almuerzo.value) return null;
    if (!_esMismoDia(ultimoRegistro.fechaHora, fechaHora)) return null;

    final minutos = fechaHora.difference(ultimoRegistro.fechaHora).inMinutes;
    final duracionTexto = minutos < 1 ? 'menos de 1 min' : '$minutos min';

    if (turno.tieneHorarioAlmuerzo) {
      final inicio = _horaEnDia(fechaHora, turno.horaAlmuerzoInicio!);
      final fin = _horaEnDia(fechaHora, turno.horaAlmuerzoFin!);
      final minutosPermitidos = fin.difference(inicio).inMinutes;
      if (minutos > minutosPermitidos) {
        final exceso = minutos - minutosPermitidos;
        return 'Se demoro $duracionTexto almorzando ($exceso min mas del horario)';
      }
    }

    return 'Se demoro $duracionTexto almorzando';
  }

  static String? evaluarMarcacion({
    required Turno? turno,
    required TipoMarcacion tipo,
    required DateTime fechaHora,
    Registro? ultimoRegistro,
    MotivoSalida? motivoSalida,
  }) {
    if (turno == null) return null;
    if (!aplicaEnFecha(turno, fechaHora)) return 'Fuera de dias de turno';

    if (tipo == TipoMarcacion.entrada) {
      if (!esPrimeraEntradaDelDia(
        ultimoRegistro: ultimoRegistro,
        fechaHora: fechaHora,
      )) {
        return evaluarRetornoAlmuerzo(
          turno: turno,
          ultimoRegistro: ultimoRegistro,
          fechaHora: fechaHora,
        );
      }
      final limite = _horaEnDia(fechaHora, turno.horaEntrada)
          .add(Duration(minutes: turno.toleranciaMinutos));
      if (fechaHora.isAfter(limite)) {
        final minutos = fechaHora.difference(limite).inMinutes;
        return 'Llegada tarde ($minutos min despues de tolerancia)';
      }
      return null;
    }

    if (!esSalidaAnticipada(turno: turno, fechaHora: fechaHora)) {
      return null;
    }

    final minutos = _horaEnDia(fechaHora, turno.horaSalida).difference(fechaHora).inMinutes;
    final base = 'Salida anticipada ($minutos min antes)';
    if (motivoSalida == null) return base;
    return '$base · ${motivoSalida.label}';
  }
}
