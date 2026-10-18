class ApiException implements Exception {
  const ApiException({required this.status, required this.message, required this.path});

  final int status;
  final String message;
  final String path;

  bool get isNetwork => status == 0;

  @override
  String toString() => message;
}
