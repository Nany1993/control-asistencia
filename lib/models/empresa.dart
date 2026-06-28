class Empresa {
  const Empresa({
    this.id,
    required this.nombre,
    this.nit = '',
    this.activa = true,
    required this.createdAt,
  });

  final int? id;
  final String nombre;
  final String nit;
  final bool activa;
  final DateTime createdAt;

  String get displayLabel =>
      nit.isNotEmpty ? '$nombre · NIT $nit' : nombre;

  Empresa copyWith({
    int? id,
    String? nombre,
    String? nit,
    bool? activa,
    DateTime? createdAt,
  }) {
    return Empresa(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nit: nit ?? this.nit,
      activa: activa ?? this.activa,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'nit': nit,
      'activa': activa ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Empresa.fromMap(Map<String, Object?> map) {
    return Empresa(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      nit: (map['nit'] as String?) ?? '',
      activa: (map['activa'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
