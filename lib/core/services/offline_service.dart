import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineAction {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory OfflineAction.fromJson(Map<String, dynamic> json) {
    return OfflineAction(
      id: json['id'],
      type: json['type'],
      data: json['data'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class OfflineService {
  static const String _storageKey = 'offline_actions_queue';
  final SharedPreferences _prefs;

  OfflineService(this._prefs);

  List<OfflineAction> getQueue() {
    final jsonString = _prefs.getString(_storageKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => OfflineAction.fromJson(e)).toList();
  }

  Future<void> queueAction(OfflineAction action) async {
    final queue = getQueue();
    queue.add(action);
    await _saveQueue(queue);
  }

  Future<void> removeAction(String id) async {
    final queue = getQueue();
    queue.removeWhere((element) => element.id == id);
    await _saveQueue(queue);
  }

  Future<void> clearQueue() async {
    await _prefs.remove(_storageKey);
  }

  Future<void> _saveQueue(List<OfflineAction> queue) async {
    final jsonString = json.encode(queue.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, jsonString);
  }
}

final offlineServiceProvider = Provider<OfflineService>((ref) {
  throw UnimplementedError('Initialize with overrides');
});
