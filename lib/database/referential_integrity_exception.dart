/// Lanzada cuando un borrado violaria integridad referencial (hay registros historicos).
class ReferentialIntegrityException implements Exception {
  ReferentialIntegrityException(this.message);

  final String message;

  @override
  String toString() => message;
}
