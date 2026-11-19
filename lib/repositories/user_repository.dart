import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class UserRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<AppUser?> getUserStream(String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return AppUser.fromMap(doc.id, doc.data()!);
    });
  }

  Future<AppUser?> getUser(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  Future<void> createUser(AppUser user) {
    return _db.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }





  /// Met à jour l'objectif de séances mensuelles du membre.
  Future<void> updateMonthlyGoal({
    required String uid,
    required int goal,
  }) {
    return _db.collection('users').doc(uid).set({
      'monthlyGoal': goal,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
