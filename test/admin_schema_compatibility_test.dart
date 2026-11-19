import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/models/models.dart';

void main() {
  group('Admin Firestore schema compatibility', () {
    test('subscription requests and approvals use the Admin member fields', () {
      final pending = Subscription.fromMap('member-uid', {
        'status': 'toVerify',
        'subscriptionName': 'Pass Mensuel',
        'isSubscriptionApproved': false,
      });

      expect(pending.userId, 'member-uid');
      expect(pending.planName, 'Pass Mensuel');
      expect(pending.isPending, isTrue);
      expect(pending.isActive, isFalse);

      final approved = Subscription.fromMap('member-uid', {
        'status': 'active',
        'subscriptionName': 'Pass Mensuel',
        'isSubscriptionApproved': true,
        'subscriptionStartAt': '2030-01-01T10:00:00.000',
        'subscriptionEndAt': '2030-02-01T10:00:00.000',
      });

      expect(approved.isActive, isTrue);
      expect(approved.startAt, DateTime(2030, 1, 1, 10));
      expect(approved.endAt, DateTime(2030, 2, 1, 10));
    });

    test('Admin plan fields determine availability and single-session type',
        () {
      final plan = SubscriptionPlan.fromMap('p1', {
        'name': 'Pass Séance Unique - Pilates',
        'priceTnd': 18.0,
        'durationMonths': 1,
        'isActive': false,
        'category': 'singleSeance',
        'targetActivity': 'Pilates',
        'benefits': ['Une séance'],
      });

      expect(plan.isActive, isFalse);
      expect(plan.isPerSession, isTrue);
      expect(plan.targetActivity, 'Pilates');
      expect(plan.price, 18);
    });

    test('subscription dates preserve ISO times and date-only values', () {
      final dateTime = parseSubscriptionDate('2030-01-01T10:00:00.000');
      final dateOnly = parseSubscriptionDate('2030-01-01');
      final approvalDate = parseSubscriptionApprovalDate({
        'status': 'active',
        'approvedAt': '2030-01-02T12:00:00.000',
        'updatedAt': '2030-01-03T12:00:00.000',
      });

      expect(dateTime, DateTime(2030, 1, 1, 10));
      expect(dateOnly, DateTime(2030, 1, 1));
      expect(approvalDate, DateTime(2030, 1, 2, 12));
      expect(
        parseSubscriptionApprovalDate(
          {'status': 'active', 'updatedAt': '2030-01-03T12:00:00.000'},
          useUpdatedAtFallback: false,
        ),
        isNull,
      );
    });

    test('approval date takes priority as subscription start date', () {
      final subscription = Subscription.fromMap('sub-approval', {
        'planName': 'Pass mensuel',
        'status': 'active',
        'subscriptionStartAt': '2030-01-01T10:00:00.000',
        'approvedAt': '2030-01-02T12:00:00.000',
      });

      expect(subscription.startAt, DateTime(2030, 1, 2, 12));
    });

    test('plan duration and type use the database fields', () {
      final plan = SubscriptionPlan.fromMap('p2', {
        'name': 'Forfait annuel',
        'durationMonths': 3,
        'subscriptionType': 'singleSession',
      });

      expect(plan.months, 3);
      expect(plan.isPerSession, isTrue);
    });

    test('monthly expiry clamps at the last day of shorter months', () {
      final plan = SubscriptionPlan.fromMap('p3', {
        'name': 'Pass mensuel',
        'durationMonths': 1,
      });

      expect(
        plan.expirationDateFrom(DateTime(2030, 1, 31, 10)),
        DateTime(2030, 2, 28, 10),
      );
    });

    test('member subscription exposes database type and calculated duration',
        () {
      final subscription = Subscription.fromMap('sub-1', {
        'planName': 'Formule spéciale',
        'status': 'active',
        'subscriptionType': 'global',
        'subscriptionStartAt': '2030-01-01',
        'subscriptionEndAt': '2030-01-11',
      });

      expect(subscription.planTypeLabel, 'Abonnement global');
      expect(subscription.durationLabel, '10 jours');

      final sessionPlan = Subscription.fromMap('sub-2', {
        'planName': 'Séance Pilates',
        'status': 'active',
        'category': 'singleSeance',
        'targetActivity': 'Pilates',
        'sessionsCount': 5,
      });

      expect(
        sessionPlan.planTypeLabel,
        'Par séance / workout · Pilates',
      );
      expect(sessionPlan.durationLabel, '5 séances');
    });

    test('per-session subscriptions never expose a stale calendar expiry', () {
      final subscription = Subscription.fromMap('sub-session', {
        'planName': 'Pack Pilates',
        'status': 'active',
        'subscriptionType': 'singleSession',
        'sessionsCount': 5,
        'subscriptionStartAt': '2030-01-01',
        'subscriptionEndAt': '2030-12-31',
      });

      expect(subscription.isPerSession, isTrue);
      expect(subscription.endAt, isNull);
      expect(subscription.durationLabel, '5 séances');
    });

    test(
        'broadcast notifications use readBy for recipient-specific unread state',
        () {
      final notification = AppNotification.fromMap(
        'broadcast-1',
        {
          'title': 'Annonce',
          'message': 'Salle ouverte',
          'target': 'members',
          'readBy': ['member-1'],
        },
        currentUid: 'member-1',
      );

      expect(notification.isRead, isTrue);
      expect(
        AppNotification.fromMap(
          'broadcast-2',
          {'title': 'Annonce', 'message': 'Salle ouverte', 'target': 'all'},
          currentUid: 'member-1',
        ).isRead,
        isFalse,
      );
    });

    test('session parsing keeps counters consistent with enrolledIds', () {
      final session = Session.fromMap('session-1', {
        'title': 'CrossFit',
        'capacity': 10,
        'enrolledCount': 2,
        'reservedCount': 4,
        'enrolledIds': ['m1', 'm2', 'm3'],
      });

      expect(session.reservedCount, 4);
      expect(session.isMemberEnrolled('m2'), isTrue);
      expect(session.spotsLeft, 6);
    });

    test('date-only expiration remains active for the whole expiration day',
        () {
      final now = DateTime.now();
      final subscription = Subscription.fromMap('sub-today', {
        'planName': 'Pass mensuel',
        'status': 'active',
        'subscriptionEndAt':
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      });

      expect(subscription.daysLeft, 0);
      expect(subscription.isActive, isTrue);
    });

    test('Admin session and reservation fields are parsed as member data', () {
      final session = Session.fromMap('session-1', {
        'title': 'Pilates',
        'type': 'Pilates',
        'coachId': 'coach-1',
        'coachName': 'Coach',
        'startAt': '2030-05-01T09:30:00.000',
        'durationMin': 60,
        'maxParticipants': 12,
        'enrolledCount': 3,
        'isApproved': false,
        'status': 'pendingApproval',
      });

      expect(session.category, 'Pilates');
      expect(session.startAt, DateTime(2030, 5, 1, 9, 30));
      expect(session.duration, 60);
      expect(session.capacity, 12);
      expect(session.reservedCount, 3);
      expect(session.active, isFalse);

      final reservation = Reservation.fromMap('reservation-1', {
        'sessionId': 'session-1',
        'sessionTitle': 'Pilates',
        'memberId': 'member-uid',
        'memberName': 'Membre',
        'memberEmail': 'member@example.com',
        'bookingTime': '2030-04-30T12:00:00.000',
        'status': 'confirmed',
      });

      expect(reservation.userId, 'member-uid');
      expect(reservation.memberEmail, 'member@example.com');
      expect(reservation.isReserved, isTrue);
      expect(reservation.createdAt, DateTime(2030, 4, 30, 12));
    });

    test('Admin notification fields map to member notification content', () {
      final notification = AppNotification.fromMap('notification-1', {
        'title': 'Séance modifiée',
        'body': 'Le cours commence plus tard.',
        'target': 'members',
        'scheduledAt': '2030-05-01T08:00:00.000',
      });

      expect(notification.message, 'Le cours commence plus tard.');
      expect(notification.target, 'members');
      expect(notification.createdAt, DateTime(2030, 5, 1, 8));
    });
  });
}
