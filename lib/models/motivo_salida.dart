enum MotivoSalida {
  almuerzo('almuerzo', 'ALMUERZO'),
  citaMedica('cita_medica', 'CITA MEDICA'),
  permiso('permiso', 'PERMISO'),
  sinPermiso('sin_permiso', 'SIN PERMISO');

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
