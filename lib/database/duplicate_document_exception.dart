class DuplicateDocumentException implements Exception {
  DuplicateDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}
