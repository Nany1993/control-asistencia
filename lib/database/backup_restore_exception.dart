class BackupRestoreException implements Exception {
  BackupRestoreException(this.message);

  final String message;

  @override
  String toString() => message;
}
