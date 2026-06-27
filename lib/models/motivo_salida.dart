enum MotivoSalida {
  almuerzo('almuerzo', 'Almuerzo'),
  citaMedica('cita_medica', 'Cita medica'),
  permiso('permiso', 'Permiso'),
  sinPermiso('sin_permiso', 'Sin permiso');

  const MotivoSalida(this.value, this.label);
  final String value;
  final String label;

  static MotivoSalida fromValue(String value) {
    return MotivoSalida.values.firstWhere((m) => m.value == value);
  }

  bool get requiereRadicado =>
      this == MotivoSalida.citaMedica || this == MotivoSalida.permiso;

  bool get permiteNotaLibre => this == MotivoSalida.sinPermiso;
}

class SalidaAnticipadaData {
  const SalidaAnticipadaData({
    required this.motivo,
    this.radicado,
    this.nota,
  });

  final MotivoSalida motivo;
  final String? radicado;
  final String? nota;
}
