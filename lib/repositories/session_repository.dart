import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class SessionRepository {
  SessionRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Session>> getSessionsStream() {
    return _db.collection('sessions').snapshots().map((snapshot) {
      final sessions = <Session>[];
      for (final doc in snapshot.docs) {
        try {
          sessions.add(Session.fromMap(doc.id, doc.data()));
        } catch (_) {}
      }

      sessions.sort((a, b) {
        final aDate = a.startAt;
        final bDate = b.startAt;
        return aDate.compareTo(bDate);
      });

      return sessions;
    });
  }

  Future<List<Session>> getSessions() async {
    final snapshot = await _db.collection('sessions').get();

    return snapshot.docs
        .map((doc) => Session.fromMap(doc.id, doc.data()))
        .toList();
  }

  Stream<List<Session>> getSessionsByCoachStream(String coachId) {
    if (coachId.isEmpty) return Stream.value([]);
    return _db
        .collection('sessions')
        .where('coachId', isEqualTo: coachId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Session.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Stream<Session?> getNearestUpcomingSessionStream() {
    return getSessionsStream().map((sessions) {
      final now = DateTime.now();
      final upcoming = sessions.where((s) => s.startAt.isAfter(now) && s.active && !s.isCancelled).toList();
      if (upcoming.isEmpty) return null;
      upcoming.sort((a, b) => a.startAt.compareTo(b.startAt));
      return upcoming.first;
    });
  }
}