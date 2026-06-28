import '../utils/texto_display.dart';

class Turno {
  const Turno({
    this.id,
    required this.nombre,
    required this.horaEntrada,
    required this.horaSalida,
    this.toleranciaMinutos = 15,
    this.diasSemana = '1,2,3,4,5',
    this.horaAlmuerzoInicio,
    this.horaAlmuerzoFin,
    this.turnoNocturno = false,
  });

  final int? id;
  final String nombre;
  final String horaEntrada;
  final String horaSalida;
  final int toleranciaMinutos;
  final String diasSemana;
  final String? horaAlmuerzoInicio;
  final String? horaAlmuerzoFin;
  final bool turnoNocturno;

  bool get esNocturno {
    if (turnoNocturno) return true;
    return _minutosDesdeMedianoche(horaSalida) <= _minutosDesdeMedianoche(horaEntrada);
  }

  static int _minutosDesdeMedianoche(String hhmm) {
    final partes = hhmm.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  bool get tieneHorarioAlmuerzo =>
      horaAlmuerzoInicio != null &&
      horaAlmuerzoInicio!.isNotEmpty &&
      horaAlmuerzoFin != null &&
      horaAlmuerzoFin!.isNotEmpty;

  String get horarioLabel {
    if (esNocturno) {
      return '$horaEntrada - $horaSalida (dia sig.)';
    }
    return '$horaEntrada - $horaSalida';
  }

  String get resumenLabel => '$nombre ($horarioLabel)';

  List<int> get diasLista {
    if (diasSemana.trim().isEmpty) return [];
    return diasSemana.split(',').map((d) => int.parse(d.trim())).toList();
  }

  Turno copyWith({
    int? id,
    String? nombre,
    String? horaEntrada,
    String? horaSalida,
    int? toleranciaMinutos,
    String? diasSemana,
    String? horaAlmuerzoInicio,
    String? horaAlmuerzoFin,
    bool clearAlmuerzo = false,
    bool? turnoNocturno,
  }) {
    return Turno(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      horaEntrada: horaEntrada ?? this.horaEntrada,
      horaSalida: horaSalida ?? this.horaSalida,
      toleranciaMinutos: toleranciaMinutos ?? this.toleranciaMinutos,
      diasSemana: diasSemana ?? this.diasSemana,
      horaAlmuerzoInicio:
          clearAlmuerzo ? null : (horaAlmuerzoInicio ?? this.horaAlmuerzoInicio),
      horaAlmuerzoFin: clearAlmuerzo ? null : (horaAlmuerzoFin ?? this.horaAlmuerzoFin),
      turnoNocturno: turnoNocturno ?? this.turnoNocturno,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': TextoDisplay.mayus(nombre),
      'hora_entrada': horaEntrada,
      'hora_salida': horaSalida,
      'tolerancia_minutos': toleranciaMinutos,
      'dias_semana': diasSemana,
      'hora_almuerzo_inicio': horaAlmuerzoInicio,
      'hora_almuerzo_fin': horaAlmuerzoFin,
      'turno_nocturno': turnoNocturno ? 1 : 0,
    };
  }

  factory Turno.fromMap(Map<String, Object?> map) {
    return Turno(
      id: map['id'] as int?,
      nombre: TextoDisplay.mayus(map['nombre'] as String),
      horaEntrada: map['hora_entrada'] as String,
      horaSalida: map['hora_salida'] as String,
      toleranciaMinutos: (map['tolerancia_minutos'] as int?) ?? 15,
      diasSemana: (map['dias_semana'] as String?) ?? '1,2,3,4,5',
      horaAlmuerzoInicio: map['hora_almuerzo_inicio'] as String?,
      horaAlmuerzoFin: map['hora_almuerzo_fin'] as String?,
      turnoNocturno: (map['turno_nocturno'] as int?) == 1,
    );
  }
}

const diasSemanaLabels = {
  1: 'LUN',
  2: 'MAR',
  3: 'MIE',
  4: 'JUE',
  5: 'VIE',
  6: 'SAB',
  7: 'DOM',
};

String diasSemanaTexto(String diasSemana) {
  final dias = diasSemana.split(',').map((d) => int.tryParse(d.trim())).whereType<int>();
  return dias.map((d) => diasSemanaLabels[d] ?? '$d').join(', ');
}
