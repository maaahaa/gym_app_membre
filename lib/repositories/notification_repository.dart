import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<AppNotification>> getUserNotificationsStream(String uid) {
    return _db.collection('notifications').snapshots().map((snapshot) {
      final docs = snapshot.docs.where((doc) {
        final data = doc.data();
        final target = data['target']?.toString();
        final targetUserId = data['targetUserId']?.toString();
        final userId = data['userId']?.toString();
        final memberId = data['memberId']?.toString();

        return target == 'all' ||
            target == 'members' ||
            (target == 'member' && targetUserId == uid) ||
            userId == uid ||
            memberId == uid;
      }).toList();

      final notifications = docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        final readBy = data['readBy'];

        data['userId'] = uid;
        data['isRead'] = readBy is List
            ? readBy.contains(uid)
            : data['isRead'] == true && data['userId'] == uid;

        return AppNotification.fromMap(doc.id, data);
      }).toList();

      notifications.sort((a, b) {
        return (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000));
      });

      return notifications;
    });
  }

  Future<void> markAsRead(String notificationId, {String? uid}) async {
    final actualUid = uid ?? '';
    await _db.collection('notifications').doc(notificationId).update({
      'readBy': FieldValue.arrayUnion([actualUid]),
    });
  }

  Future<void> markAllAsRead(String uid) async {
    final snapshot = await _db.collection('notifications').get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'readBy': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }
}