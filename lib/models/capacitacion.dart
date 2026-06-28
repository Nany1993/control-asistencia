import '../utils/texto_display.dart';

enum ResultadoCapacitacion {
  ejecutada('ejecutada', 'EJECUTADA'),
  noEjecutada('no_ejecutada', 'NO EJECUTADA');

  const ResultadoCapacitacion(this.value, this.label);
  final String value;
  final String label;

  static ResultadoCapacitacion fromValue(String value) {
    return ResultadoCapacitacion.values.firstWhere((r) => r.value == value);
  }
}

class Capacitacion {
  const Capacitacion({
    this.id,
    required this.nombre,
    required this.temas,
    required this.expositor,
    required this.fecha,
    this.empresaId,
    this.fotoGeneralPath,
    this.activa = true,
    this.resultado,
    this.cerradaEn,
    this.cierreAutomatico = false,
    required this.createdAt,
    this.empresaNombre,
    this.totalAsistentes,
  });

  final int? id;
  final String nombre;
  final String temas;
  final String expositor;
  final DateTime fecha;
  final int? empresaId;
  final String? fotoGeneralPath;
  final bool activa;
  final String? resultado;
  final DateTime? cerradaEn;
  final bool cierreAutomatico;
  final DateTime createdAt;
  final String? empresaNombre;
  final int? totalAsistentes;

  DateTime get fechaDia => DateTime(fecha.year, fecha.month, fecha.day);

  bool get tieneFotoGeneral =>
      fotoGeneralPath != null && fotoGeneralPath!.isNotEmpty;

  String? get resultadoLabel {
    if (resultado == null) return null;
    try {
      return ResultadoCapacitacion.fromValue(resultado!).label;
    } catch (_) {
      return resultado;
    }
  }

  String get estadoLabel => activa ? 'ABIERTA' : 'CERRADA';

  static String dateKey(DateTime date) {
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': TextoDisplay.mayus(nombre),
      'temas': TextoDisplay.mayus(temas),
      'expositor': TextoDisplay.mayus(expositor),
      'fecha': dateKey(fecha),
      'empresa_id': empresaId,
      'foto_general_path': fotoGeneralPath,
      'activa': activa ? 1 : 0,
      'resultado': resultado,
      'cerrada_en': cerradaEn?.toIso8601String(),
      'cierre_automatico': cierreAutomatico ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Capacitacion.fromMap(Map<String, Object?> map) {
    final fechaStr = map['fecha'] as String;
    final fechaParts = fechaStr.split('-');
    final fecha = fechaParts.length == 3
        ? DateTime(
            int.parse(fechaParts[0]),
            int.parse(fechaParts[1]),
            int.parse(fechaParts[2]),
          )
        : DateTime.parse(fechaStr);

    return Capacitacion(
      id: map['id'] as int?,
      nombre: TextoDisplay.mayus(map['nombre'] as String),
      temas: TextoDisplay.mayus(map['temas'] as String),
      expositor: TextoDisplay.mayus(map['expositor'] as String),
      fecha: fecha,
      empresaId: map['empresa_id'] as int?,
      fotoGeneralPath: map['foto_general_path'] as String?,
      activa: (map['activa'] as int) == 1,
      resultado: map['resultado'] as String?,
      cerradaEn: map['cerrada_en'] != null
          ? DateTime.parse(map['cerrada_en'] as String)
          : null,
      cierreAutomatico: (map['cierre_automatico'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      empresaNombre: TextoDisplay.mayusOpcional(map['empresa_nombre'] as String?),
      totalAsistentes: map['total_asistentes'] as int?,
    );
  }

  Capacitacion copyWith({
    int? id,
    String? nombre,
    String? temas,
    String? expositor,
    DateTime? fecha,
    int? empresaId,
    bool clearEmpresaId = false,
    String? fotoGeneralPath,
    bool clearFotoGeneral = false,
    bool? activa,
    String? resultado,
    bool clearResultado = false,
    DateTime? cerradaEn,
    bool clearCerradaEn = false,
    bool? cierreAutomatico,
    DateTime? createdAt,
    String? empresaNombre,
    int? totalAsistentes,
  }) {
    return Capacitacion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      temas: temas ?? this.temas,
      expositor: expositor ?? this.expositor,
      fecha: fecha ?? this.fecha,
      empresaId: clearEmpresaId ? null : (empresaId ?? this.empresaId),
      fotoGeneralPath: clearFotoGeneral
          ? null
          : (fotoGeneralPath ?? this.fotoGeneralPath),
      activa: activa ?? this.activa,
      resultado: clearResultado ? null : (resultado ?? this.resultado),
      cerradaEn: clearCerradaEn ? null : (cerradaEn ?? this.cerradaEn),
      cierreAutomatico: cierreAutomatico ?? this.cierreAutomatico,
      createdAt: createdAt ?? this.createdAt,
      empresaNombre: empresaNombre ?? this.empresaNombre,
      totalAsistentes: totalAsistentes ?? this.totalAsistentes,
    );
  }
}
