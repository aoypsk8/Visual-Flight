class ApiResponse<T> {
  final bool success;
  final int? statusCode;
  final String? message;
  final T? data;

  const ApiResponse({
    required this.success,
    this.statusCode,
    this.message,
    this.data,
  });
}
