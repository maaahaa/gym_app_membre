import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/models/models.dart';

void main() {
  group('Adhérent Features & Firebase Model Tests', () {
    test('1. Sessions: only future, non-cancelled and non-full are available', () {
      final now = DateTime.now();

      final futureSession = Session.fromMap('s1', {
        'title': 'CrossFit',
        'type': 'Force',
        'coachId': 'c1',
        'coachName': 'Coach A',
        'startAt': now.add(const Duration(hours: 2)).toIso8601String(),
        'durationMin': 45,
        'capacity': 10,
        'reservedCount': 5,
        'status': 'approved',
        'active': true,
      });

      expect(futureSession.isFuture, isTrue);
      expect(futureSession.isPast, isFalse);
      expect(futureSession.isCancelled, isFalse);
      expect(futureSession.isFull, isFalse);
      expect(futureSession.isAvailable, isTrue);

      final pastSession = Session.fromMap('s2', {
        'title': 'Yoga Morning',
        'type': 'Bien-être',
        'coachId': 'c1',
        'startAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'durationMin': 60,
        'capacity': 10,
        'reservedCount': 2,
        'active': true,
      });

      expect(pastSession.isPast, isTrue);
      expect(pastSession.isAvailable, isFalse);

      final fullSession = Session.fromMap('s3', {
        'title': 'Spinning',
        'startAt': now.add(const Duration(hours: 4)).toIso8601String(),
        'capacity': 10,
        'reservedCount': 10,
        'active': true,
      });

      expect(fullSession.isFull, isTrue);
      expect(fullSession.isAvailable, isFalse);

      final cancelledSession = Session.fromMap('s4', {
        'title': 'Pilates',
        'startAt': now.add(const Duration(hours: 5)).toIso8601String(),
        'status': 'cancelled',
        'capacity': 10,
        'reservedCount': 2,
      });

      expect(cancelledSession.isCancelled, isTrue);
      expect(cancelledSession.isAvailable, isFalse);
    });

    test('2. Coaches: only coaches with type = gym are identified as gym coaches', () {
      final gymCoach = Coach.fromMap('c_gym', {
        'name': 'Sarah Gym',
        'type': 'gym',
        'specialties': ['Pilates', 'Yoga'],
        'role': 'coach',
      });

      expect(gymCoach.type, 'gym');
      expect(gymCoach.isGymCoach, isTrue);
      expect(gymCoach.isPrivateCoach, isFalse);

      final privateCoach = Coach.fromMap('c_priv', {
        'name': 'Alex Private',
        'type': 'private',
        'specialties': ['CrossFit'],
        'role': 'coach',
      });

      expect(privateCoach.type, 'private');
      expect(privateCoach.isGymCoach, isFalse);
      expect(privateCoach.isPrivateCoach, isTrue);
    });

    test('3. Private Coach on Member Profile: hasPrivateCoach and privateCoachId', () {
      final regularMember = AppUser.fromMap('m1', {
        'name': 'Adhérent Simple',
        'email': 'simple@test.com',
        'role': 'member',
      });

      expect(regularMember.hasPrivateCoach, isFalse);
      expect(regularMember.privateCoachId, isNull);

      final privateMember = AppUser.fromMap('m2', {
        'name': 'Adhérent VIP',
        'email': 'vip@test.com',
        'role': 'member',
        'hasPrivateCoach': true,
        'privateCoachId': 'c_priv_123',
      });

      expect(privateMember.hasPrivateCoach, isTrue);
      expect(privateMember.privateCoachId, 'c_priv_123');
    });

    test('4. Private Coach Program: parsed with days, duration and exercises', () {
      final program = Program.fromMap('prog_1', {
        'memberId': 'm2',
        'coachId': 'c_priv_123',
        'title': 'Prise de masse 6 semaines',
        'durationWeeks': 6,
        'trainingDays': ['Lundi', 'Mercredi', 'Vendredi'],
        'notes': 'Bien s\'échauffer 10 min.',
        'exercises': [
          {'name': 'Développé couché', 'sets': 4, 'reps': '10', 'restSeconds': 90},
          {'name': 'Squat barre', 'sets': 4, 'reps': '8', 'restSeconds': 120},
        ],
      });

      expect(program.memberId, 'm2');
      expect(program.coachId, 'c_priv_123');
      expect(program.trainingDays, ['Lundi', 'Mercredi', 'Vendredi']);
      expect(program.duration, '6 semaines');
      expect(program.exercises.length, 2);
      expect(program.exercises.first.name, 'Développé couché');
    });

    test('5. Subscription: real dates, no createdAt fallback, safe daysLeft calculation', () {
      final now = DateTime.now();
      final sub = Subscription.fromMap('sub_1', {
        'userId': 'm1',
        'subscriptionName': 'Abonnement Annuel',
        'status': 'active',
        'subscriptionStartAt': '2026-01-01T00:00:00.000',
        'subscriptionEndAt': now.add(const Duration(days: 30)).toIso8601String(),
        'createdAt': '2025-01-01T00:00:00.000', // Devrait être ignoré pour startAt
      });

      expect(sub.startAt, isNotNull);
      expect(sub.startAt!.year, 2026);
      expect(sub.daysLeft, inInclusiveRange(29, 31));
      expect(sub.isActive, isTrue);
    });

    test('6. Notifications: mapped to user and correctly reflects read status', () {
      final unreadNotif = AppNotification.fromMap('n1', {
        'userId': 'm1',
        'title': 'Nouvelle séance',
        'body': 'Séance ajoutée',
        'isRead': false,
      });

      expect(unreadNotif.userId, 'm1');
      expect(unreadNotif.isRead, isFalse);

      final readNotif = AppNotification.fromMap('n2', {
        'memberId': 'm1',
        'title': 'Rappel',
        'message': 'Votre séance commence bientôt',
        'read': true,
      });

      expect(readNotif.userId, 'm1');
      expect(readNotif.isRead, isTrue);
    });
  });
}

