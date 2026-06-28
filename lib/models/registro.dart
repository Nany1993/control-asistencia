import 'motivo_salida.dart';

enum TipoMarcacion {
  entrada('entrada'),
  salida('salida');

  const TipoMarcacion(this.value);
  final String value;

  static TipoMarcacion fromValue(String value) {
    return TipoMarcacion.values.firstWhere((t) => t.value == value);
  }

  String get label => value == 'entrada' ? 'Entrada' : 'Salida';
}

class Registro {
  const Registro({
    this.id,
    required this.empresaId,
    required this.empleadoId,
    required this.tipo,
    required this.fechaHora,
    required this.fotoPath,
    this.observacion,
    this.motivoSalida,
    this.radicado,
    this.turnoId,
    this.empresaNombre,
    this.empleadoNombre,
    this.empleadoTipoDocumento,
    this.empleadoNumeroDocumento,
    this.empleadoEsExterno,
    this.empleadoCargo,
    this.turnoNombre,
  });

  final int? id;
  final int empresaId;
  final int empleadoId;
  final TipoMarcacion tipo;
  final DateTime fechaHora;
  final String fotoPath;
  final String? observacion;
  final String? motivoSalida;
  final String? radicado;
  final int? turnoId;
  final String? empresaNombre;
  final String? empleadoNombre;
  final String? empleadoTipoDocumento;
  final String? empleadoNumeroDocumento;
  final bool? empleadoEsExterno;
  final String? empleadoCargo;
  final String? turnoNombre;

  String get tipoPersonaLabel =>
      (empleadoEsExterno ?? false) ? 'Externo' : 'Interno';

  String? get motivoSalidaLabel {
    if (motivoSalida == null) return null;
    try {
      return MotivoSalida.fromValue(motivoSalida!).label;
    } catch (_) {
      return motivoSalida;
    }
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'empresa_id': empresaId,
      'empleado_id': empleadoId,
      'tipo': tipo.value,
      'fecha_hora': fechaHora.toIso8601String(),
      'foto_path': fotoPath,
      'observacion': observacion,
      'motivo_salida': motivoSalida,
      'radicado': radicado,
      'turno_id': turnoId,
      'empresa_nombre': empresaNombre ?? '',
      'empleado_cargo': empleadoCargo ?? '',
      'empleado_nombre': empleadoNombre ?? '',
      'empleado_tipo_documento': empleadoTipoDocumento ?? '',
      'empleado_numero_documento': empleadoNumeroDocumento ?? '',
    };
  }

  factory Registro.fromMap(Map<String, Object?> map) {
    return Registro(
      id: map['id'] as int?,
      empresaId: map['empresa_id'] as int,
      empleadoId: map['empleado_id'] as int,
      tipo: TipoMarcacion.fromValue(map['tipo'] as String),
      fechaHora: DateTime.parse(map['fecha_hora'] as String),
      fotoPath: map['foto_path'] as String,
      observacion: map['observacion'] as String?,
      motivoSalida: map['motivo_salida'] as String?,
      radicado: map['radicado'] as String?,
      turnoId: map['turno_id'] as int?,
      empresaNombre: map['empresa_nombre'] as String?,
      empleadoNombre: map['empleado_nombre'] as String?,
      empleadoTipoDocumento: map['empleado_tipo_documento'] as String?,
      empleadoNumeroDocumento: map['empleado_numero_documento'] as String?,
      empleadoEsExterno: (map['empleado_es_externo'] as int?) == 1,
      empleadoCargo: map['empleado_cargo'] as String?,
      turnoNombre: map['turno_nombre'] as String?,
    );
  }
}
