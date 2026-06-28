import 'tipo_documento.dart';

class Empleado {
  const Empleado({
    this.id,
    required this.empresaId,
    required this.nombre,
    required this.tipoDocumento,
    required this.numeroDocumento,
    this.cargo = '',
    this.esExterno = false,
    this.turnoIds = const [],
    this.activo = true,
    required this.createdAt,
    this.turnosNombre,
    this.empresaNombre,
  });

  final int? id;
  final int empresaId;
  final String nombre;
  final String tipoDocumento;
  final String numeroDocumento;
  final String cargo;
  final bool esExterno;
  final List<int> turnoIds;
  final bool activo;
  final DateTime createdAt;
  final String? turnosNombre;
  final String? empresaNombre;

  String get documentoLabel => '$tipoDocumento $numeroDocumento';

  String get nombreConDocumento => '$nombre ($documentoLabel)';

  String get tipoPersonaLabel => esExterno ? 'Externo' : 'Interno';

  /// Alias para compatibilidad con pantallas existentes.
  String? get turnoNombre => turnosNombre;

  Empleado copyWith({
    int? id,
    int? empresaId,
    String? nombre,
    String? tipoDocumento,
    String? numeroDocumento,
    String? cargo,
    bool? esExterno,
    List<int>? turnoIds,
    bool? activo,
    DateTime? createdAt,
    String? turnosNombre,
    String? empresaNombre,
  }) {
    return Empleado(
      id: id ?? this.id,
      empresaId: empresaId ?? this.empresaId,
      nombre: nombre ?? this.nombre,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      cargo: cargo ?? this.cargo,
      esExterno: esExterno ?? this.esExterno,
      turnoIds: turnoIds ?? this.turnoIds,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      turnosNombre: turnosNombre ?? this.turnosNombre,
      empresaNombre: empresaNombre ?? this.empresaNombre,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'empresa_id': empresaId,
      'nombre': nombre,
      'tipo_documento': tipoDocumento,
      'numero_documento': numeroDocumento,
      'cargo': cargo,
      'es_externo': esExterno ? 1 : 0,
      'turno_id': null,
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
      cargo: (map['cargo'] as String?) ?? '',
      esExterno: (map['es_externo'] as int?) == 1,
      activo: (map['activo'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      turnosNombre: (map['turnos_nombre'] as String?) ??
          (map['turno_nombre'] as String?),
      empresaNombre: map['empresa_nombre'] as String?,
    );
  }
}
