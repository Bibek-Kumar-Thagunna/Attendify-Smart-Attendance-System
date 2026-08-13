/// Stub implementation for unsupported platforms
Future<void> downloadFileImpl({
  required String filename,
  required List<int> bytes,
  String? mimeType,
}) async {
  throw UnsupportedError('File download is not supported on this platform');
}
