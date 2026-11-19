import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class WorkoutRepository {
  WorkoutRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Workout>> getUserWorkoutsStream(String uid) {
    return _db
        .collection('workouts')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final workouts = snapshot.docs
          .map((doc) => Workout.fromMap(doc.id, doc.data()))
          .toList();

      workouts.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return workouts;
    });
  }

  Future<void> addWorkout({
    required String uid,
    required String sessionTitle,
    required int durationMinutes,
    required int caloriesBurned,
    required int volumeKg,
    DateTime? completedAt,
  }) async {
    await _db.collection('workouts').add({
      'userId': uid,
      'memberId': uid,
      'sessionTitle': sessionTitle,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt)
          : FieldValue.serverTimestamp(),
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'volumeKg': volumeKg,
    });
  }
}