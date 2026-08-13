import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/services/notification_service.dart';

/// Mobile implementation of file download
Future<void> downloadFileImpl({
  required String filename,
  required List<int> bytes,
  String? mimeType,
}) async {
  try {
    // 1. Request Storage Permissions
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt <= 32) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Storage permission denied');
          }
        }
      }
    }

    // 2. Get Downloads Directory
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      // Fallback if standard path doesn't exist (unlikely)
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) {
      throw Exception('Could not access storage directory');
    }

    // 3. Save File
    // Ensure filename has extension
    final name = filename;
    final path = '${directory.path}/$name';
    final file = File(path);

    // Show progress notification
    final notificationService = NotificationService();
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await notificationService.showProgressNotification(
      id: notificationId,
      title: 'Saving file...',
      body: name,
      progress: 0,
      maxProgress: 100,
    );

    // Write bytes
    await file.writeAsBytes(bytes);

    // Update to complete
    await notificationService.showProgressNotification(
      id: notificationId,
      title: 'Download Complete',
      body: 'Tap to open $name',
      progress: 100,
      maxProgress: 100,
    );

    // Show clickable completion notification (re-using ID to update/replace)
    await notificationService.showNotification(
      id: notificationId,
      title: 'Download Complete',
      body: 'Tap to open $name',
      payload: path,
    );

    // 4. Open File
    try {
      final result = await OpenFile.open(path);
      if (result.type != ResultType.done) {
        debugPrint('Could not open file: ${result.message}');
      }
    } catch (e) {
      // Ignore MissingPluginException or other open errors, as the file is already saved
      debugPrint('Error opening file: $e');
    }
  } catch (e) {
    throw Exception('Failed to download file: $e');
  }
}
