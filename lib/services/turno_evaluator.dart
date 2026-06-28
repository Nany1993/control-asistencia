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

  static DateTime _horaEnDia(DateTime fecha, String hhmm) {
    final partes = hhmm.split(':');
    final h = int.parse(partes[0]);
    final m = int.parse(partes[1]);
    return DateTime(fecha.year, fecha.month, fecha.day, h, m);
  }

  /// Turno asignado que mejor corresponde al dia y hora de [fechaHora].
  static Turno? turnoParaFecha(List<Turno> turnos, DateTime fechaHora) {
    final candidatos =
        turnos.where((t) => aplicaEnFecha(t, fechaHora)).toList();
    if (candidatos.isEmpty) return null;
    if (candidatos.length == 1) return candidatos.first;

    for (final turno in candidatos) {
      final inicio = _horaEnDia(fechaHora, turno.horaEntrada);
      final fin = _horaEnDia(fechaHora, turno.horaSalida);
      if (!fechaHora.isBefore(inicio) && !fechaHora.isAfter(fin)) {
        return turno;
      }
    }

    candidatos.sort((a, b) {
      final diffA = fechaHora
          .difference(_horaEnDia(fechaHora, a.horaEntrada))
          .inMinutes
          .abs();
      final diffB = fechaHora
          .difference(_horaEnDia(fechaHora, b.horaEntrada))
          .inMinutes
          .abs();
      return diffA.compareTo(diffB);
    });
    return candidatos.first;
  }

  static bool esSalidaAnticipada({
    required Turno turno,
    required DateTime fechaHora,
  }) {
    if (!aplicaEnFecha(turno, fechaHora)) return false;
    final horaSalida = _horaEnDia(fechaHora, turno.horaSalida);
    return fechaHora.isBefore(horaSalida);
  }

  /// Retraso solo en la primera entrada del dia calendario.
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
    return false;
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
        return null;
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

    final minutos =
        _horaEnDia(fechaHora, turno.horaSalida).difference(fechaHora).inMinutes;
    final base = 'Salida anticipada ($minutos min antes)';
    if (motivoSalida == null) return base;
    return '$base · ${motivoSalida.label}';
  }
}
