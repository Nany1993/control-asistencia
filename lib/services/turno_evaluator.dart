import '../models/motivo_salida.dart';
import '../models/registro.dart';
import '../models/turno.dart';
import '../utils/texto_display.dart';

class TurnoEvaluator {
  TurnoEvaluator._();

  static int minutosDesdeMedianoche(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  static bool esNocturno(Turno turno) => turno.esNocturno;

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

  /// Fin esperado del turno segun la hora de entrada registrada.
  static DateTime finTurnoEsperado(Registro entrada, Turno turno) {
    final dia = DateTime(
      entrada.fechaHora.year,
      entrada.fechaHora.month,
      entrada.fechaHora.day,
    );
    if (esNocturno(turno)) {
      return _horaEnDia(dia.add(const Duration(days: 1)), turno.horaSalida);
    }
    return _horaEnDia(dia, turno.horaSalida);
  }

  static bool turnoNocturnoAbierto({
    required Registro entradaAbierta,
    required Turno turno,
    required DateTime ahora,
  }) {
    if (!esNocturno(turno)) return false;
    return !ahora.isAfter(finTurnoEsperado(entradaAbierta, turno));
  }

  /// Turno asignado que mejor corresponde al dia y hora de [fechaHora].
  static Turno? turnoParaFecha(List<Turno> turnos, DateTime fechaHora) {
    final candidatos =
        turnos.where((t) => aplicaEnFecha(t, fechaHora)).toList();
    if (candidatos.isEmpty) return null;
    if (candidatos.length == 1) return candidatos.first;

    for (final turno in candidatos) {
      if (_fechaDentroDeTurno(turno, fechaHora)) {
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

  /// Turno vigente para marcar (respeta entrada nocturna abierta del dia anterior).
  static Turno? turnoParaMarcacion(
    List<Turno> turnos,
    Registro? ultimo,
    DateTime fechaHora, {
    Turno? turnoEntradaPendiente,
  }) {
    if (ultimo != null &&
        ultimo.tipo == TipoMarcacion.entrada &&
        turnoEntradaPendiente != null &&
        turnoNocturnoAbierto(
          entradaAbierta: ultimo,
          turno: turnoEntradaPendiente,
          ahora: fechaHora,
        )) {
      return turnoEntradaPendiente;
    }
    return turnoParaFecha(turnos, fechaHora);
  }

  static bool _fechaDentroDeTurno(Turno turno, DateTime fechaHora) {
    final dia = DateTime(fechaHora.year, fechaHora.month, fechaHora.day);
    final inicio = _horaEnDia(dia, turno.horaEntrada);
    if (esNocturno(turno)) {
      final fin = _horaEnDia(dia.add(const Duration(days: 1)), turno.horaSalida);
      return !fechaHora.isBefore(inicio) && fechaHora.isBefore(fin);
    }
    final fin = _horaEnDia(dia, turno.horaSalida);
    return !fechaHora.isBefore(inicio) && !fechaHora.isAfter(fin);
  }

  static bool esSalidaAnticipada({
    required Turno turno,
    required DateTime fechaHora,
    Registro? entradaAbierta,
  }) {
    if (esNocturno(turno) &&
        entradaAbierta != null &&
        entradaAbierta.tipo == TipoMarcacion.entrada) {
      final fin = finTurnoEsperado(entradaAbierta, turno);
      return fechaHora.isBefore(fin);
    }
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
    if (!aplicaEnFecha(turno, fechaHora) &&
        !(esNocturno(turno) &&
            ultimoRegistro != null &&
            ultimoRegistro.tipo == TipoMarcacion.entrada &&
            turnoNocturnoAbierto(
              entradaAbierta: ultimoRegistro,
              turno: turno,
              ahora: fechaHora,
            ))) {
      return 'FUERA DE DIAS DE TURNO';
    }

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
        return 'LLEGADA TARDE ($minutos MIN DESPUES DE TOLERANCIA)';
      }
      return null;
    }

    final entradaAbierta =
        ultimoRegistro?.tipo == TipoMarcacion.entrada ? ultimoRegistro : null;
    if (!esSalidaAnticipada(
      turno: turno,
      fechaHora: fechaHora,
      entradaAbierta: entradaAbierta,
    )) {
      return null;
    }

    final horaSalidaReferencia = entradaAbierta != null && esNocturno(turno)
        ? finTurnoEsperado(entradaAbierta, turno)
        : _horaEnDia(fechaHora, turno.horaSalida);
    final minutos = horaSalidaReferencia.difference(fechaHora).inMinutes;
    final base = 'SALIDA ANTICIPADA ($minutos MIN ANTES)';
    if (motivoSalida == null) return base;
    return '$base · ${TextoDisplay.mayus(motivoSalida.label)}';
  }
}
