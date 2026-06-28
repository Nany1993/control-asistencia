class DuplicateNitException implements Exception {
  DuplicateNitException(this.message);

  final String message;

  @override
  String toString() => message;
}
