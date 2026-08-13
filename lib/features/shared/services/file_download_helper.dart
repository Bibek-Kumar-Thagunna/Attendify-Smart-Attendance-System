import 'file_download_stub.dart'
    if (dart.library.io) 'file_download_mobile.dart'
    if (dart.library.html) 'file_download_web.dart';

/// Universal file download helper
/// Automatically selects web or mobile implementation based on platform
Future<void> downloadFile({
  required String filename,
  required List<int> bytes,
  String? mimeType,
}) => downloadFileImpl(filename: filename, bytes: bytes, mimeType: mimeType);
