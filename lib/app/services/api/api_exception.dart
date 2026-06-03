class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// Validation errors from the server (e.g. {"email": ["already taken"]})
  final Map<String, dynamic>? errors;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => message;
}
