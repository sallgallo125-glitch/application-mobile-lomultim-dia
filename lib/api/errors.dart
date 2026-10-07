/// Mirrors ../mobile-app/src/api/errors.ts
class ApiHttpError implements Exception {
  final String path;
  final int status;

  /// Server error code and user-facing message, when the body provides them.
  final String? code;
  final String? message;

  const ApiHttpError(this.path, this.status, {this.code, this.message});

  @override
  String toString() => 'Request to $path failed with status $status';
}

class ApiParseError implements Exception {
  final String path;
  final Object cause;

  const ApiParseError(this.path, this.cause);

  @override
  String toString() =>
      'Response from $path did not match the expected contract: $cause';
}
