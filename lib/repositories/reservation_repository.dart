import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class ReservationRepository {
  ReservationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Reservation>> getUserReservationsStream(String uid) {
    return _db
        .collection('reservations')
        .where('memberId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final reservations = snapshot.docs
          .map((doc) => Reservation.fromMap(doc.id, doc.data()))
          .toList();

      reservations.sort((a, b) {
        final aDate = a.startAt;
        final bDate = b.startAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return aDate.compareTo(bDate);
      });

      return reservations;
    });
  }

  Future<void> cancelReservation(String uid, String reservationId) async {
    final ref = _db.collection('reservations').doc(reservationId);
    final doc = await ref.get();

    if (!doc.exists) {
      throw Exception('RESERVATION_NOT_FOUND');
    }

    if (doc.data()?['memberId'] != uid) {
      throw Exception('NOT_AUTHORIZED');
    }

    await ref.update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reserveSession({
    String? uid,
    String? memberId,
    String? memberName,
    String? memberEmail,
    String? paymentType,
    required Session session,
  }) async {
    final actualUid = uid ?? memberId ?? '';
    final sessionRef = _db.collection('sessions').doc(session.id);
    final reservationRef = _db.collection('reservations').doc(
      '${actualUid}_${session.id}',
    );

    await _db.runTransaction((transaction) async {
      final sessionSnapshot = await transaction.get(sessionRef);
      final reservationSnapshot = await transaction.get(reservationRef);

      if (!sessionSnapshot.exists) {
        throw Exception('SESSION_NOT_FOUND');
      }

      final data = sessionSnapshot.data()!;
      final existing = reservationSnapshot.data();

      if (reservationSnapshot.exists &&
          (existing?['status'] ?? 'reserved') == 'reserved') {
        return;
      }

      final startValue = data['startAt'];
      if (startValue is! Timestamp) {
        throw Exception('INVALID_SESSION_DATE');
      }

      if (startValue.toDate().isBefore(DateTime.now())) {
        throw Exception('SESSION_PASSED');
      }

      final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
      final reservedCount = (data['reservedCount'] as num?)?.toInt() ?? 0;

      if (capacity <= 0 || reservedCount >= capacity) {
        throw Exception('SESSION_FULL');
      }

      transaction.set(reservationRef, {
        'memberId': actualUid,
        'userId': actualUid,
        'sessionId': session.id,
        'sessionTitle': data['title'] ?? 'Séance',
        'category': data['category'] ?? '',
        'coachId': data['coachId'] ?? '',
        'coachName': data['coachName'] ?? data['coach'] ?? '',
        'studio': data['studio'] ?? '',
        'startAt': startValue,
        'durationMinutes': data['durationMinutes'] ?? data['duration'] ?? 0,
        'status': 'reserved',
        'paymentType': paymentType ?? 'subscription',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}