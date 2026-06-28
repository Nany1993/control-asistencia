class AsistenciaCapacitacion {
  const AsistenciaCapacitacion({
    this.id,
    required this.capacitacionId,
    required this.empleadoId,
    required this.fechaHora,
    required this.fotoPath,
    this.empleadoNombre,
    this.empleadoTipoDocumento,
    this.empleadoNumeroDocumento,
    this.empleadoEsExterno,
    this.empleadoCargo,
    this.empresaNombre,
    this.capacitacionNombre,
  });

  final int? id;
  final int capacitacionId;
  final int empleadoId;
  final DateTime fechaHora;
  final String fotoPath;
  final String? empleadoNombre;
  final String? empleadoTipoDocumento;
  final String? empleadoNumeroDocumento;
  final bool? empleadoEsExterno;
  final String? empleadoCargo;
  final String? empresaNombre;
  final String? capacitacionNombre;

  String get tipoPersonaLabel =>
      (empleadoEsExterno ?? false) ? 'Externo' : 'Interno';

  String get documentoLabel =>
      '${empleadoTipoDocumento ?? ''} ${empleadoNumeroDocumento ?? ''}'.trim();

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'capacitacion_id': capacitacionId,
      'empleado_id': empleadoId,
      'fecha_hora': fechaHora.toIso8601String(),
      'foto_path': fotoPath,
      'empleado_cargo': empleadoCargo ?? '',
      'empleado_nombre': empleadoNombre ?? '',
      'empleado_tipo_documento': empleadoTipoDocumento ?? '',
      'empleado_numero_documento': empleadoNumeroDocumento ?? '',
    };
  }

  factory AsistenciaCapacitacion.fromMap(Map<String, Object?> map) {
    return AsistenciaCapacitacion(
      id: map['id'] as int?,
      capacitacionId: map['capacitacion_id'] as int,
      empleadoId: map['empleado_id'] as int,
      fechaHora: DateTime.parse(map['fecha_hora'] as String),
      fotoPath: map['foto_path'] as String,
      empleadoNombre: map['empleado_nombre'] as String?,
      empleadoTipoDocumento: map['empleado_tipo_documento'] as String?,
      empleadoNumeroDocumento: map['empleado_numero_documento'] as String?,
      empleadoEsExterno: (map['empleado_es_externo'] as int?) == 1,
      empleadoCargo: map['empleado_cargo'] as String?,
      empresaNombre: map['empresa_nombre'] as String?,
      capacitacionNombre: map['capacitacion_nombre'] as String?,
    );
  }
}
