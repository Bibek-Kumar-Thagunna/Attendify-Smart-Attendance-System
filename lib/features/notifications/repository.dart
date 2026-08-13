import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class NotificationModel {
  final String id;
  final String recipientUid;
  final String senderUid;
  final String senderName;
  final String senderRollNumber;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  final bool read;
  final Map<String, dynamic> metadata;
  final String? institutionId;

  NotificationModel({
    required this.id,
    required this.recipientUid,
    required this.senderUid,
    required this.senderName,
    required this.senderRollNumber,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    required this.read,
    required this.metadata,
    this.institutionId,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      recipientUid: data['recipientUid'] ?? '',
      senderUid: data['senderUid'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRollNumber: data['senderRollNumber'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
      metadata: data['metadata'] as Map<String, dynamic>? ?? {},
      institutionId: data['institutionId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recipientUid': recipientUid,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderRollNumber': senderRollNumber,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
      'metadata': metadata,
      'institutionId': institutionId,
    };
  }
}

class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createNotification(NotificationModel notification) async {
    await _firestore.collection('notifications').add(notification.toMap());
  }

  Stream<List<NotificationModel>> streamNotifications(
    String userId, {
    String? role,
  }) {
    // 1. Stream personal notifications
    final personalStream = _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: userId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );

    // 2. Stream global notifications (if role is provided)
    Stream<List<NotificationModel>> globalStream;
    if (role != null) {
      globalStream = CombineLatestStream.combine3(
        _firestore
            .collection('global_notifications')
            .where('targetRole', whereIn: ['all', role])
            .snapshots(),
        _firestore
            .collection('users')
            .doc(userId)
            .collection('notification_states')
            .snapshots(),
        _firestore.collection('users').doc(userId).snapshots(),
        (
          QuerySnapshot globalSnap,
          QuerySnapshot stateSnap,
          DocumentSnapshot userDoc,
        ) {
          final userData = userDoc.data() as Map<String, dynamic>?;
          final userInstitutionCode = userData?['institutionCode'] as String?;

          final stateMap = {
            for (var doc in stateSnap.docs)
              doc.id: doc.data() as Map<String, dynamic>,
          };

          return globalSnap.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;

                // Filter by Institution
                final targetInstitutionId = data['institutionId'] as String?;
                if (targetInstitutionId != null &&
                    targetInstitutionId.isNotEmpty) {
                  if (userInstitutionCode != targetInstitutionId) {
                    return null;
                  }
                }

                final state = stateMap[doc.id];
                if (state != null && state['deleted'] == true) {
                  return null;
                }

                final isRead = state != null && state['read'] == true;

                return NotificationModel(
                  id: doc.id,
                  recipientUid: userId,
                  senderUid: 'system',
                  senderName: 'System',
                  senderRollNumber: '',
                  title: data['title'] ?? '',
                  message: data['message'] ?? '',
                  type: 'broadcast',
                  timestamp:
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  read: isRead,
                  metadata: {},
                  institutionId: data['institutionId'] as String?,
                );
              })
              .whereType<NotificationModel>()
              .toList();
        },
      );
    } else {
      globalStream = Stream.value([]);
    }

    // 3. Merge and sort
    return CombineLatestStream.list([personalStream, globalStream]).map((
      lists,
    ) {
      final allNotifications = <NotificationModel>[];
      for (var list in lists) {
        allNotifications.addAll(list);
      }
      allNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allNotifications;
    });
  }

  Future<void> markAsRead(String notificationId, {String? userId}) async {
    // Try updating personal notification first
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
      });
    } catch (e) {
      // If not found, it might be a global notification
      if (e is FirebaseException && e.code == 'not-found' && userId != null) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('notification_states')
            .doc(notificationId)
            .set({
              'read': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      } else {
        rethrow;
      }
    }
  }

  Future<void> markAllAsRead(String userId, {String? role}) async {
    final batch = _firestore.batch();

    // 1. Mark personal notifications as read
    final personalSnap = await _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();

    for (var doc in personalSnap.docs) {
      batch.update(doc.reference, {'read': true});
    }

    // 2. Mark global notifications as read (by creating state entries)
    if (role != null) {
      final globalSnap = await _firestore
          .collection('global_notifications')
          .where('targetRole', whereIn: ['all', role])
          .get();

      for (var doc in globalSnap.docs) {
        final stateRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('notification_states')
            .doc(doc.id);

        batch.set(stateRef, {
          'read': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }

  Future<void> clearAllNotifications(String userId, {String? role}) async {
    final batch = _firestore.batch();

    // 1. Delete personal notifications
    final personalSnap = await _firestore
        .collection('notifications')
        .where('recipientUid', isEqualTo: userId)
        .get();

    for (var doc in personalSnap.docs) {
      batch.delete(doc.reference);
    }

    // 2. Mark global notifications as deleted
    if (role != null) {
      final globalSnap = await _firestore
          .collection('global_notifications')
          .where('targetRole', whereIn: ['all', role])
          .get();

      for (var doc in globalSnap.docs) {
        final stateRef = _firestore
            .collection('users')
            .doc(userId)
            .collection('notification_states')
            .doc(doc.id);

        batch.set(stateRef, {
          'deleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }
}
