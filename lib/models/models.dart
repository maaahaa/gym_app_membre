
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

DateTime? parseSubscriptionDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final match = RegExp(
      r'^(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})$',
    ).firstMatch(text);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);

      final date = DateTime(year, month, day);

      if (date.day == day &&
          date.month == month &&
          date.year == year) {
        return date;
      }
    }
  }

  return null;
}

DateTime? parseSubscriptionApprovalDate(dynamic value, {bool useUpdatedAtFallback = true}) {
  if (value is Map<String, dynamic>) {
    final approvedAt = parseSubscriptionDate(value['approvedAt']);
    if (approvedAt != null) return approvedAt;
    if (useUpdatedAtFallback) {
      return parseSubscriptionDate(value['updatedAt']);
    }
    return null;
  }
  return parseSubscriptionDate(value);
}

int _toInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _toString(dynamic value, [String fallback = '']) {
  return value?.toString() ?? fallback;
}

// --------------------------------------------------
// 1. APP USER
// --------------------------------------------------

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final DateTime? createdAt;
  final bool isActive;
  final bool hasPrivateCoach;
  final String? privateCoachId;
  final int monthlyGoal;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = 'member',
    this.createdAt,
    this.isActive = true,
    this.hasPrivateCoach = false,
    this.privateCoachId,
    this.monthlyGoal = 18,
  });

  String? get coachId => privateCoachId;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    final activeValue = map['isActive'] ?? map['active'];
    final status = (map['status'] ?? 'active').toString().toLowerCase();
    final pCoachId = _toString(map['privateCoachId'] ?? map['coachId']);

    return AppUser(
      id: id,
      name: _toString(map['name'] ?? map['fullName']),
      email: _toString(map['email']),
      phone: _toString(map['phone']),
      role: _toString(map['role'], 'member'),
      createdAt: parseSubscriptionDate(map['createdAt']),
      isActive: activeValue is bool
          ? activeValue
          : !['inactive', 'disabled', 'blocked', 'suspended']
              .contains(status),
      hasPrivateCoach: map['hasPrivateCoach'] as bool? ?? pCoachId.isNotEmpty,
      privateCoachId: pCoachId.isEmpty ? null : pCoachId,
      monthlyGoal: _toInt(map['monthlyGoal'], 18),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'fullName': name,
      'email': email,
      'phone': phone,
      'role': role,
      'isActive': isActive,
      'hasPrivateCoach': hasPrivateCoach,
      'privateCoachId': privateCoachId,
      'monthlyGoal': monthlyGoal,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

// --------------------------------------------------
// 2. COACH
// --------------------------------------------------

class Coach {
  final String id;
  final String name;
  final String initials;
  final String bio;
  final List<String> specialties;
  final String? photoUrl;
  final String type;
  final String? experience;
  final String email;
  final String phone;

  const Coach({
    required this.id,
    required this.name,
    required this.initials,
    required this.bio,
    required this.specialties,
    this.photoUrl,
    this.type = 'gym',
    this.experience,
    this.email = '',
    this.phone = '',
  });

  String get firstName => name.trim().split(' ').first;
  bool get isGymCoach => type.toLowerCase() == 'gym';
  bool get isPrivateCoach => type.toLowerCase() == 'private';

  factory Coach.fromMap(String id, Map<String, dynamic> map) {
    final name = _toString(map['name'] ?? map['fullName'], 'Coach');
    final parts = name.trim().split(RegExp(r'\s+'));

    final generatedInitials = parts.length > 1
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : parts.first[0].toUpperCase();

    final specs = map['specialties'];

    return Coach(
      id: id,
      name: name,
      initials: _toString(map['initials'], generatedInitials),
      bio: _toString(map['bio'] ?? map['description']),
      specialties: specs is List
          ? specs.map((e) => e.toString()).toList()
          : (map['specialty'] != null ? [map['specialty'].toString()] : []),
      photoUrl: map['photoUrl']?.toString() ?? map['avatar']?.toString() ?? map['image']?.toString(),
      type: _toString(map['type'] ?? map['coachType'], 'gym'),
      experience: map['experience']?.toString() ?? map['exp']?.toString(),
      email: _toString(map['email']),
      phone: _toString(map['phone']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'initials': initials,
      'bio': bio,
      'specialties': specialties,
      'photoUrl': photoUrl,
      'type': type,
      'experience': experience,
      'email': email,
      'phone': phone,
    };
  }
}

// --------------------------------------------------
// 3. SESSION
// --------------------------------------------------

class Session {
  final String id;
  final String title;
  final String category;
  final String coachId;
  final String coach;
  final String studio;
  final DateTime startAt;
  final int duration;
  final int capacity;
  final int reservedCount;
  final bool active;
  final String status;
  final List<String> enrolledIds;

  const Session({
    required this.id,
    required this.title,
    required this.category,
    required this.coachId,
    required this.coach,
    required this.studio,
    required this.startAt,
    required this.duration,
    required this.capacity,
    required this.reservedCount,
    this.active = true,
    this.status = 'approved',
    this.enrolledIds = const [],
  });

  bool get isFuture => startAt.isAfter(DateTime.now());
  bool get isPast => startAt.isBefore(DateTime.now());
  bool get isFinished => isPast;
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isFull => capacity > 0 && reservedCount >= capacity;
  bool get isAvailable => isFuture && !isCancelled && !isFull;

  bool isMemberEnrolled(String userId) => enrolledIds.contains(userId);

  int get spotsLeft =>
      (capacity - reservedCount).clamp(0, capacity).toInt();

  String get time {
    final local = startAt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  int get day => startAt.day;

  Color get color {
    switch (category) {
      case 'Force':
        return AppColors.orange;
      case 'Bien-être':
        return AppColors.purple;
      default:
        return AppColors.lime;
    }
  }

  factory Session.fromMap(String id, Map<String, dynamic> map) {
    final enrolled = map['enrolledIds'] ?? map['enrolled'];
    final isApproved = map['isApproved'] as bool? ?? true;
    final status = _toString(map['status'], 'approved');
    final isActiveMap = map['active'] as bool? ?? true;
    final statLower = status.toLowerCase();

    return Session(
      id: id,
      title: _toString(map['title'], 'Séance'),
      category: _toString(map['category'] ?? map['type'], 'Cardio'),
      coachId: _toString(map['coachId']),
      coach: _toString(map['coach'] ?? map['coachName']),
      studio: _toString(map['studio']),
      startAt: parseSubscriptionDate(map['startAt']) ?? DateTime.now(),
      duration: _toInt(map['durationMin'] ?? map['duration'] ?? map['durationMinutes'], 45),
      capacity: _toInt(map['capacity'] ?? map['maxParticipants'], 10),
      reservedCount: _toInt(map['reservedCount'] ?? map['enrolledCount']),
      active: isActiveMap &&
          isApproved &&
          statLower != 'pendingapproval' &&
          statLower != 'pending_approval' &&
          statLower != 'toverify',
      status: status,
      enrolledIds: enrolled is List ? enrolled.map((e) => e.toString()).toList() : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'coachId': coachId,
      'coach': coach,
      'studio': studio,
      'startAt': Timestamp.fromDate(startAt),
      'duration': duration,
      'capacity': capacity,
      'reservedCount': reservedCount,
      'active': active,
      'status': status,
      'enrolledIds': enrolledIds,
    };
  }
}

// --------------------------------------------------
// 4. RESERVATION
// --------------------------------------------------

class Reservation {
  final String id;
  final String userId;
  final String sessionId;
  final String sessionTitle;
  final String category;
  final String coachName;
  final String studio;
  final DateTime startAt;
  final int durationMinutes;
  final String status;
  final DateTime? createdAt;
  final String? memberEmail;

  const Reservation({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.sessionTitle,
    required this.category,
    required this.coachName,
    required this.studio,
    required this.startAt,
    required this.durationMinutes,
    this.status = 'reserved',
    this.createdAt,
    this.memberEmail,
  });

  bool get isReserved =>
      status.toLowerCase() == 'reserved' ||
      status.toLowerCase() == 'confirmed' ||
      status.toLowerCase() == 'approved';

  factory Reservation.fromMap(String id, Map<String, dynamic> map) {
    return Reservation(
      id: id,
      userId: _toString(map['userId'] ?? map['memberId']),
      sessionId: _toString(map['sessionId'], id),
      sessionTitle: _toString(
        map['sessionTitle'] ?? map['title'],
        'Séance',
      ),
      category: _toString(map['category']),
      coachName: _toString(map['coachName'] ?? map['coach']),
      studio: _toString(map['studio']),
      startAt: parseSubscriptionDate(map['startAt']) ?? DateTime.now(),
      durationMinutes: _toInt(
        map['durationMinutes'] ?? map['duration'],
      ),
      status: _toString(map['status'], 'reserved'),
      createdAt: parseSubscriptionDate(map['createdAt'] ?? map['bookingTime']),
      memberEmail: map['memberEmail']?.toString() ?? map['email']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'memberId': userId,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'category': category,
      'coachName': coachName,
      'studio': studio,
      'startAt': Timestamp.fromDate(startAt),
      'durationMinutes': durationMinutes,
      'status': status,
      'memberEmail': memberEmail,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

// --------------------------------------------------
// 5. EXERCISE
// --------------------------------------------------

class Exercise {
  final String id;
  final String name;
  final int sets;
  final String reps;
  final int restSeconds;
  final int order;

  const Exercise({
    required this.id,
    required this.name,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    this.order = 0,
  });

  factory Exercise.fromMap(String id, Map<String, dynamic> map) {
    return Exercise(
      id: id,
      name: _toString(map['name'], 'Exercice'),
      sets: _toInt(map['sets']),
      reps: _toString(map['reps']),
      restSeconds: _toInt(map['restSeconds']),
      order: _toInt(map['order']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'sets': sets,
      'reps': reps,
      'restSeconds': restSeconds,
      'order': order,
    };
  }
}

// --------------------------------------------------
// 6. PROGRAM
// --------------------------------------------------

class Program {
  final String id;
  final String memberId;
  final String coachId;
  final String coachName;
  final String title;
  final String notes;
  final bool active;
  final DateTime? createdAt;
  final List<Exercise> exercises;
  final int durationWeeks;
  final List<String> trainingDays;

  const Program({
    required this.id,
    required this.memberId,
    required this.coachId,
    required this.coachName,
    required this.title,
    this.notes = '',
    this.active = true,
    this.createdAt,
    this.exercises = const [],
    this.durationWeeks = 0,
    this.trainingDays = const [],
  });

  String get duration => durationWeeks > 0 ? '$durationWeeks semaines' : '';

  factory Program.fromMap(
      String id,
      Map<String, dynamic> map, {
        List<Exercise> exercises = const [],
      }) {
    final tDays = map['trainingDays'];
    final rawExercises = map['exercises'];
    final parsedExercises = exercises.isNotEmpty
        ? exercises
        : (rawExercises is List
            ? rawExercises
                .map((e) => e is Map<String, dynamic>
                    ? Exercise.fromMap('', e)
                    : null)
                .whereType<Exercise>()
                .toList()
                .cast<Exercise>()
            : <Exercise>[]);

    return Program(
      id: id,
      memberId: _toString(map['memberId'] ?? map['userId']),
      coachId: _toString(map['coachId']),
      coachName: _toString(map['coachName'] ?? map['coach']),
      title: _toString(map['title'], 'Programme'),
      notes: _toString(map['notes'] ?? map['tips']),
      active: map['active'] as bool? ?? true,
      createdAt: parseSubscriptionDate(map['createdAt']),
      exercises: parsedExercises,
      durationWeeks: _toInt(map['durationWeeks'] ?? map['duration'], 0),
      trainingDays: tDays is List ? tDays.map((e) => e.toString()).toList() : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberId': memberId,
      'coachId': coachId,
      'coachName': coachName,
      'title': title,
      'notes': notes,
      'active': active,
      'durationWeeks': durationWeeks,
      'trainingDays': trainingDays,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

// --------------------------------------------------
// 7. SUBSCRIPTION
// --------------------------------------------------

class Subscription {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final String status;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? targetActivity;
  final bool? isSubscriptionApproved;
  final String subscriptionType;
  final int? sessionsCount;

  const Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.status,
    this.startAt,
    this.endAt,
    this.targetActivity,
    this.isSubscriptionApproved,
    this.subscriptionType = 'global',
    this.sessionsCount,
  });

  bool get isPerSession =>
      subscriptionType.toLowerCase() == 'singlesession' ||
      planName.toLowerCase().contains('séance') ||
      planName.toLowerCase().contains('session');

  bool get isExpired =>
      !isPerSession && endAt != null && DateTime(endAt!.year, endAt!.month, endAt!.day).isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  bool get isActive =>
      !isExpired &&
          (status.toLowerCase() == 'active' ||
              status.toLowerCase() == 'actif');

  bool get isPending =>
      isSubscriptionApproved == false ||
      status.toLowerCase() == 'toverify' ||
      status.toLowerCase() == 'pending' ||
      status.toLowerCase() == 'en_attente' ||
      status.toLowerCase() == 'pendingapproval';

  bool get isRejected =>
      status.toLowerCase() == 'rejected' ||
      status.toLowerCase() == 'refuse' ||
      status.toLowerCase() == 'refusé';

  int get daysLeft {
    if (endAt == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(endAt!.year, endAt!.month, endAt!.day);
    final diff = endDate.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  int get priceTnd => 0;
  int? get sessionsLeft => sessionsCount;

  String get planTypeLabel {
    if (subscriptionType == 'global') return 'Abonnement global';
    if (isPerSession) {
      return targetActivity != null && targetActivity!.isNotEmpty
          ? 'Par séance / workout · $targetActivity'
          : 'Par séance / workout';
    }
    if (targetActivity != null && targetActivity!.isNotEmpty) {
      return '$planName · $targetActivity';
    }
    return planName;
  }

  String get durationLabel {
    if (isPerSession && sessionsCount != null) {
      return '$sessionsCount séances';
    }
    if (startAt != null && endAt != null) {
      final diff = endAt!.difference(startAt!).inDays;
      if (diff > 0) return '$diff jours';
    }
    return endAt != null ? '$daysLeft jours' : 'Illimité';
  }

  String get statusLabel {
    if (isExpired) return 'EXPIRÉ';

    switch (status.toLowerCase()) {
      case 'active':
      case 'actif':
        return 'ACTIF';
      case 'expiring':
        return 'BIENTÔT EXPIRÉ';
      case 'toverify':
      case 'pending':
      case 'en_attente':
      case 'pendingapproval':
        return 'EN ATTENTE';
      case 'rejected':
      case 'refuse':
      case 'refusé':
        return 'REFUSÉ';
      default:
        return 'INACTIF';
    }
  }

  factory Subscription.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    final subType = _toString(map['subscriptionType'] ?? (map['category'] == 'singleSeance' ? 'singleSession' : 'global'));
    final isPerSessionCheck = subType.toLowerCase() == 'singlesession' || map['category'] == 'singleSeance';
    final approvedAt = parseSubscriptionDate(map['approvedAt'] ?? map['approved_at']);
    final startAtParsed = parseSubscriptionDate(
      map['subscriptionStartAt'] ??
          map['startAt'] ??
          map['start_at'] ??
          map['date_debut'] ??
          map['dateDebut'] ??
          map['startDate'],
    );
    final finalStartAt = approvedAt ?? startAtParsed ?? (map['status'] == 'active' ? DateTime.now().subtract(const Duration(days: 15)) : null);
    final endAtParsed = parseSubscriptionDate(
      map['subscriptionEndAt'] ??
          map['endAt'] ??
          map['end_at'] ??
          map['date_expiration'] ??
          map['dateExpiration'] ??
          map['date_fin'] ??
          map['dateFin'] ??
          map['endDate'],
    );
    final finalEndAt = endAtParsed ?? (finalStartAt != null && map['status'] == 'active' && !isPerSessionCheck ? finalStartAt.add(const Duration(days: 30)) : null);

    return Subscription(
      id: id,
      userId: _toString(map['userId'] ?? map['memberId'] ?? id),
      planId: _toString(map['planId']),
      planName: _toString(
        map['subscriptionName'] ?? map['planName'] ?? map['name'],
        'PREMIUM',
      ),
      status: _toString(map['status'], 'inactive'),
      startAt: finalStartAt,
      endAt: isPerSessionCheck ? null : finalEndAt,
      targetActivity: map['targetActivity']?.toString(),
      isSubscriptionApproved: map['isSubscriptionApproved'] as bool? ?? (map['status'] == 'active' ? true : null),
      subscriptionType: subType,
      sessionsCount: map['sessionsCount'] != null ? _toInt(map['sessionsCount']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planId': planId,
      'planName': planName,
      'status': status,
      'targetActivity': targetActivity,
      'subscriptionType': subscriptionType,
      'sessionsCount': sessionsCount,
      'startAt': startAt != null
          ? Timestamp.fromDate(startAt!)
          : null,
      'endAt': endAt != null
          ? Timestamp.fromDate(endAt!)
          : null,
    };
  }
}

// --------------------------------------------------
// 8. SUBSCRIPTION PLAN
// --------------------------------------------------

class SubscriptionPlan {
  final String id;
  final String name;
  final int price;
  final int months;
  final List<String> benefits;
  final bool isActive;
  final bool isPerSession;
  final String? targetActivity;
  final int? sessionsCount;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.months,
    required this.benefits,
    this.isActive = true,
    this.isPerSession = false,
    this.targetActivity,
    this.sessionsCount,
  });

  String get duration => months == 1 ? '1 mois' : '$months mois';
  String get durationDisplay => duration;

  DateTime expirationDateFrom(DateTime date) {
    final targetMonth = date.month + months;
    final targetYear = date.year + (targetMonth - 1) ~/ 12;
    final adjustedMonth = ((targetMonth - 1) % 12) + 1;
    final lastDayOfTargetMonth = DateTime(targetYear, adjustedMonth + 1, 0).day;
    final targetDay = date.day > lastDayOfTargetMonth ? lastDayOfTargetMonth : date.day;
    return DateTime(targetYear, adjustedMonth, targetDay, date.hour, date.minute, date.second, date.millisecond);
  }

  factory SubscriptionPlan.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    final list = map['benefits'];
    final subType = _toString(map['subscriptionType'] ?? (map['category'] == 'singleSeance' ? 'singleSession' : ''));
    final isPerSession = subType.toLowerCase() == 'singlesession' || map['category'] == 'singleSeance';

    return SubscriptionPlan(
      id: id,
      name: _toString(map['name']),
      price: _toInt(map['price'] ?? map['priceTnd']),
      months: _toInt(
        map['months'] ?? map['durationMonths'],
        1,
      ),
      benefits: list is List
          ? list.map((e) => e.toString()).toList()
          : [],
      isActive: map['isActive'] as bool? ?? true,
      isPerSession: isPerSession,
      targetActivity: map['targetActivity']?.toString(),
      sessionsCount: map['sessionsCount'] != null ? _toInt(map['sessionsCount']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'months': months,
      'benefits': benefits,
      'isActive': isActive,
      'isPerSession': isPerSession,
      'targetActivity': targetActivity,
      'sessionsCount': sessionsCount,
    };
  }
}

// --------------------------------------------------
// 9. WORKOUT
// --------------------------------------------------

class Workout {
  final String id;
  final String userId;
  final String sessionTitle;
  final DateTime completedAt;
  final int durationMinutes;
  final int caloriesBurned;
  final int volumeKg;

  const Workout({
    required this.id,
    required this.userId,
    required this.sessionTitle,
    required this.completedAt,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.volumeKg,
  });

  factory Workout.fromMap(String id, Map<String, dynamic> map) {
    return Workout(
      id: id,
      userId: _toString(map['userId'] ?? map['memberId']),
      sessionTitle: _toString(
        map['sessionTitle'] ?? map['title'],
        'Séance',
      ),
      completedAt: parseSubscriptionDate(
        map['completedAt'] ?? map['date'],
      ) ?? DateTime.now(),
      durationMinutes: _toInt(
        map['durationMinutes'] ?? map['duration'],
      ),
      caloriesBurned: _toInt(map['caloriesBurned']),
      volumeKg: _toInt(map['volumeKg']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sessionTitle': sessionTitle,
      'completedAt': Timestamp.fromDate(completedAt),
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'volumeKg': volumeKg,
    };
  }
}

// --------------------------------------------------
// 10. APP NOTIFICATION
// --------------------------------------------------

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool isRead;
  final String? type;
  final String target;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.createdAt,
    this.isRead = false,
    this.type,
    this.target = 'all',
  });

  IconData get icon {
    switch (type) {
      case 'reservation':
        return Icons.check_circle_outline_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'subscription':
        return Icons.credit_card_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  factory AppNotification.fromMap(
      String id,
      Map<String, dynamic> map, {
        String? currentUid,
      }) {
    final readBy = map['readBy'];
    final isReadByList = currentUid != null && readBy is List ? readBy.contains(currentUid) : false;
    final isReadFlag = map['isRead'] as bool? ?? map['read'] as bool? ?? false;

    return AppNotification(
      id: id,
      userId: _toString(
        map['userId'] ?? map['memberId'] ?? map['targetUserId'] ?? currentUid ?? '',
      ),
      title: _toString(map['title']),
      message: _toString(map['message'] ?? map['body']),
      createdAt: parseSubscriptionDate(map['createdAt'] ?? map['scheduledAt']),
      isRead: isReadByList || isReadFlag,
      type: map['type']?.toString(),
      target: _toString(map['target'], 'all'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'target': target,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'isRead': isRead,
      'type': type,
    };
  }
}
