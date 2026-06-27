import 'tipo_documento.dart';

class Empleado {
  const Empleado({
    this.id,
    required this.empresaId,
    required this.nombre,
    required this.tipoDocumento,
    required this.numeroDocumento,
    this.esExterno = false,
    this.turnoId,
    this.activo = true,
    required this.createdAt,
    this.turnoNombre,
  });

  final int? id;
  final int empresaId;
  final String nombre;
  final String tipoDocumento;
  final String numeroDocumento;
  final bool esExterno;
  final int? turnoId;
  final bool activo;
  final DateTime createdAt;
  final String? turnoNombre;

  String get documentoLabel => '$tipoDocumento $numeroDocumento';

  String get nombreConDocumento => '$nombre ($documentoLabel)';

  String get tipoPersonaLabel => esExterno ? 'Externo' : 'Interno';

  Empleado copyWith({
    int? id,
    int? empresaId,
    String? nombre,
    String? tipoDocumento,
    String? numeroDocumento,
    bool? esExterno,
    int? turnoId,
    bool clearTurnoId = false,
    bool? activo,
    DateTime? createdAt,
    String? turnoNombre,
  }) {
    return Empleado(
      id: id ?? this.id,
      empresaId: empresaId ?? this.empresaId,
      nombre: nombre ?? this.nombre,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      esExterno: esExterno ?? this.esExterno,
      turnoId: clearTurnoId ? null : (turnoId ?? this.turnoId),
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      turnoNombre: turnoNombre ?? this.turnoNombre,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'empresa_id': empresaId,
      'nombre': nombre,
      'tipo_documento': tipoDocumento,
      'numero_documento': numeroDocumento,
      'es_externo': esExterno ? 1 : 0,
      'turno_id': turnoId,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Empleado.fromMap(Map<String, Object?> map) {
    return Empleado(
      id: map['id'] as int?,
      empresaId: map['empresa_id'] as int,
      nombre: map['nombre'] as String,
      tipoDocumento: (map['tipo_documento'] as String?) ?? TipoDocumento.cc.codigo,
      numeroDocumento: (map['numero_documento'] as String?) ?? '',
      esExterno: (map['es_externo'] as int?) == 1,
      turnoId: map['turno_id'] as int?,
      activo: (map['activo'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      turnoNombre: map['turno_nombre'] as String?,
    );
  }
}
