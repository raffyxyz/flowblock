/// Exception thrown when task or subtask validation fails.
class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
