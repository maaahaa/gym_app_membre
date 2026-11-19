import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class CoachRepository {
  CoachRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Coach>> getCoachesStream() {
    return _db.collection('coaches').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Coach.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Stream<Coach?> getCoachStream(String coachId) {
    if (coachId.isEmpty) return Stream.value(null);
    return _db.collection('coaches').doc(coachId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return Coach.fromMap(doc.id, doc.data()!);
    });
  }
}