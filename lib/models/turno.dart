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
  });

  final int? id;
  final String nombre;
  final String horaEntrada;
  final String horaSalida;
  final int toleranciaMinutos;
  final String diasSemana;
  final String? horaAlmuerzoInicio;
  final String? horaAlmuerzoFin;

  bool get tieneHorarioAlmuerzo =>
      horaAlmuerzoInicio != null &&
      horaAlmuerzoInicio!.isNotEmpty &&
      horaAlmuerzoFin != null &&
      horaAlmuerzoFin!.isNotEmpty;

  String get horarioLabel => '$horaEntrada - $horaSalida';

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
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'hora_entrada': horaEntrada,
      'hora_salida': horaSalida,
      'tolerancia_minutos': toleranciaMinutos,
      'dias_semana': diasSemana,
      'hora_almuerzo_inicio': horaAlmuerzoInicio,
      'hora_almuerzo_fin': horaAlmuerzoFin,
    };
  }

  factory Turno.fromMap(Map<String, Object?> map) {
    return Turno(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      horaEntrada: map['hora_entrada'] as String,
      horaSalida: map['hora_salida'] as String,
      toleranciaMinutos: (map['tolerancia_minutos'] as int?) ?? 15,
      diasSemana: (map['dias_semana'] as String?) ?? '1,2,3,4,5',
      horaAlmuerzoInicio: map['hora_almuerzo_inicio'] as String?,
      horaAlmuerzoFin: map['hora_almuerzo_fin'] as String?,
    );
  }
}

const diasSemanaLabels = {
  1: 'Lun',
  2: 'Mar',
  3: 'Mie',
  4: 'Jue',
  5: 'Vie',
  6: 'Sab',
  7: 'Dom',
};

String diasSemanaTexto(String diasSemana) {
  final dias = diasSemana.split(',').map((d) => int.tryParse(d.trim())).whereType<int>();
  return dias.map((d) => diasSemanaLabels[d] ?? '$d').join(', ');
}
