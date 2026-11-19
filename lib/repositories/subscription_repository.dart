import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';

class SubscriptionRepository {
  SubscriptionRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<Subscription?> getUserSubscriptionStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((userDoc) {
      if (!userDoc.exists) return null;

      final userData = userDoc.data() ?? {};
      final embedded = userData['subscription'];

      if (embedded is Map<String, dynamic>) {
        return Subscription.fromMap('current', embedded);
      }

      if (userData.containsKey('subscriptionName') ||
          userData.containsKey('planId') ||
          userData.containsKey('status') ||
          userData.containsKey('isSubscriptionApproved')) {
        return Subscription.fromMap('current', userData);
      }

      return null;
    });
  }

  Stream<List<SubscriptionPlan>> getSubscriptionPlansStream() {
    return _db.collection('subscription_plans').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => SubscriptionPlan.fromMap(doc.id, doc.data()))
          .toList();
    });
  }

  Future<void> requestSubscription({
    required String uid,
    required SubscriptionPlan plan,
  }) async {
    final now = DateTime.now();
    final endDate = plan.isPerSession ? null : plan.expirationDateFrom(now);

    final dataToSave = {
      'userId': uid,
      'memberId': uid,
      'planId': plan.id,
      'planName': plan.name,
      'subscriptionName': plan.name,
      'status': 'pending',
      'isSubscriptionApproved': false,
      'subscriptionStartAt': Timestamp.fromDate(now),
      'subscriptionEndAt': endDate != null ? Timestamp.fromDate(endDate) : null,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('users').doc(uid).set(dataToSave, SetOptions(merge: true));
    await _db.collection('subscriptions').add(dataToSave);
  }
}