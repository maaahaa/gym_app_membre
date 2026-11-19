import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class ProgramRepository {
  ProgramRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<Program?> getPrivateCoachProgramStream({
    required String memberId,
    required String coachId,
  }) {
    return _db
        .collection('programs')
        .where('memberId', isEqualTo: memberId)
        .where('coachId', isEqualTo: coachId)
        .snapshots()
        .asyncMap((snapshot) async {
      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      final exercisesSnapshot =
          await doc.reference.collection('exercises').get();

      final exercises = exercisesSnapshot.docs
          .map((exercise) =>
              Exercise.fromMap(exercise.id, exercise.data()))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));

      return Program.fromMap(
        doc.id,
        data,
        exercises: exercises.isNotEmpty
            ? exercises
            : (data['exercises'] is List
                ? (data['exercises'] as List)
                    .map((e) => Exercise.fromMap('', e is Map<String, dynamic> ? e : {}))
                    .toList()
                : []),
      );
    });
  }
}