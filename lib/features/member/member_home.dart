import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/models.dart';
import '../../repositories/coach_repository.dart';
import '../../repositories/reservation_repository.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/subscription_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../services/auth_service.dart';
import 'profile_sub_screens.dart';
import 'program_screen.dart';
import 'subscriptions_screen.dart';

class MemberHome extends StatelessWidget {
  const MemberHome({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final uid = user?.uid ?? '';

    final userRepo = UserRepository();
    final subRepo = SubscriptionRepository();
    final workoutRepo = WorkoutRepository();
    final reservationRepo = ReservationRepository();
    final sessionRepo = SessionRepository();
    final coachRepo = CoachRepository();

    return StreamBuilder<AppUser?>(
      stream: userRepo.getUserStream(uid),
      builder: (context, userSnapshot) {
        final appUser = userSnapshot.data;
        final name = appUser?.name.trim() ?? '';
        final displayName =
            name.isNotEmpty ? name.split(RegExp(r'\s+')).first : 'Utilisateur';

        final hasPrivateCoach = appUser?.hasPrivateCoach == true &&
            appUser?.privateCoachId != null &&
            appUser!.privateCoachId!.isNotEmpty;
        final privateCoachId = appUser?.privateCoachId ?? '';

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            // 1. En-tête utilisateur
            StreamBuilder<List<AppNotification>>(
              stream: NotificationRepository().getUserNotificationsStream(uid),
              builder: (context, notificationSnapshot) {
                final unreadCount = (notificationSnapshot.data ?? [])
                    .where((notification) => !notification.isRead)
                    .length;

                return PageHeader(
                  eyebrow: 'BON RETOUR,',
                  title: 'Salut, $displayName',
                  showBell: true,
                  hasUnread: unreadCount > 0,
                  unreadCount: unreadCount,
                  onBell: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 22),

            // 2. Carte abonnement
            _subscriptionCard(context, subRepo, uid),

            // 3. Section COACH PRIVÉ (uniquement si le membre a un coach privé)
            if (hasPrivateCoach) ...[
              const SizedBox(height: 26),
              SectionHeader(
                'Mon coach privé',
                action: 'Programme',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProgramScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              _privateCoachCard(context, coachRepo, privateCoachId),
            ],

            const SizedBox(height: 26),

            // 4. Activité de la semaine
            const SectionHeader(
              'Ton activité',
              action: 'Cette semaine',
            ),

            const SizedBox(height: 14),

            _activityStats(workoutRepo, uid),

            const SizedBox(height: 26),

            // 5. Prochaine séance (la plus proche chronologiquement dans le futur)
            SectionHeader(
              'Prochaine séance',
              action: 'Voir tout',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyReservationsScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            _nextSession(context, reservationRepo, sessionRepo, uid),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // CARTE COACH PRIVÉ (affichée uniquement si hasPrivateCoach == true)
  // --------------------------------------------------

  Widget _privateCoachCard(
      BuildContext context, CoachRepository coachRepo, String coachId) {
    return StreamBuilder<Coach?>(
      stream: coachRepo.getCoachStream(coachId),
      builder: (context, snapshot) {
        final coach = snapshot.data;

        return AppCard(
          padding: const EdgeInsets.all(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProgramScreen(),
              ),
            );
          },
          child: Row(
            children: [
              coach?.photoUrl != null && coach!.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        coach.photoUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            AvatarCircle(coach.initials, size: 48),
                      ),
                    )
                  : AvatarCircle(coach?.initials ?? 'CP', size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PillBadge('COACH PRIVÉ ASSIGNÉ',
                        dot: false, color: AppColors.lime),
                    const SizedBox(height: 4),
                    Text(
                      coach?.name ?? 'Coach Privé',
                      style: AppText.body(15, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Appuie pour voir ton programme personnalisé',
                      style: AppText.body(11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // ABONNEMENT
  // --------------------------------------------------

  Widget _subscriptionCard(
      BuildContext context, SubscriptionRepository subRepo, String uid) {
    return StreamBuilder<Subscription?>(
      stream: subRepo.getUserSubscriptionStream(uid),
      builder: (context, snapshot) {
        final sub = snapshot.data;
        final isActive = sub != null && sub.isActive;
        String startDate = '';
        String endDate = '';
        String expirationLabel = '';

        if (sub?.startAt != null) {
          startDate = _formatDate(sub!.startAt!);
        }
        if (sub?.endAt != null) {
          endDate = _formatDate(sub!.endAt!);
          expirationLabel = endDate;
        } else if (sub?.isPerSession == true) {
          expirationLabel = 'Sans expiration par date';
        }

        final daysLeft = sub?.daysLeft;

        return AppCard(
          padding: const EdgeInsets.all(22),
          radius: 26,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2B3512),
              Color(0xFF12140E),
              Color(0xFF0E100B),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PillBadge(
                isActive
                    ? 'ABONNEMENT ACTIF'
                    : sub?.isPending == true
                        ? 'DEMANDE EN ATTENTE'
                        : sub?.statusLabel ?? 'ABONNEMENT',
                color: isActive
                    ? AppColors.lime
                    : sub?.isPending == true
                        ? AppColors.orange
                        : AppColors.muted,
              ),
              const SizedBox(height: 30),
              Text(
                sub?.planName ?? 'AUCUN ABONNEMENT',
                style: AppText.title(30),
              ),
              const SizedBox(height: 6),
              Text(
                isActive
                    ? (endDate.isNotEmpty
                        ? 'Valable jusqu’au $endDate'
                        : 'Ton abonnement est actif.')
                    : sub?.isPending == true
                        ? 'Ton abonnement sera activé après validation par l’administration.'
                        : sub?.isRejected == true
                            ? 'Ta demande a été refusée. Choisis une autre formule.'
                            : 'Découvre nos formules d’abonnement.',
                style: AppText.body(
                  11.5,
                  color: Colors.white70,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Type : ${sub.planTypeLabel} · Durée : ${sub.durationLabel}',
                  style: AppText.body(11.5, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  'Début : ${startDate.isNotEmpty ? startDate : '--'}',
                  style: AppText.body(11.5, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expiration : ${expirationLabel.isNotEmpty ? expirationLabel : '--'}',
                  style: AppText.body(11.5, color: Colors.white70),
                ),
              ],
              if (isActive && daysLeft != null) ...[
                const SizedBox(height: 4),
                Text(
                  daysLeft == 0
                      ? 'Expire aujourd’hui'
                      : '$daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}',
                  style: AppText.body(
                    11,
                    color: daysLeft <= 5 ? AppColors.orange : AppColors.lime,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionsScreen(),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Voir mon abonnement',
                      style: AppText.body(
                        12,
                        color: AppColors.lime,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.lime,
                      size: 16,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 190,
                color: AppColors.lime,
              ),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // STATISTIQUES DE LA SEMAINE
  // --------------------------------------------------

  Widget _activityStats(WorkoutRepository workoutRepo, String uid) {
    return StreamBuilder<List<Workout>>(
      stream: workoutRepo.getUserWorkoutsStream(uid),
      builder: (context, snapshot) {
        final allWorkouts = snapshot.data ?? [];
        final now = DateTime.now();
        final startOfWeek = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));

        final weeklyWorkouts = allWorkouts.where((w) {
          return !w.completedAt.isBefore(startOfWeek) &&
              w.completedAt.isBefore(startOfWeek.add(const Duration(days: 7)));
        }).toList();

        final sessions = weeklyWorkouts.length;
        final minutes =
            weeklyWorkouts.fold<int>(0, (sum, w) => sum + w.durationMinutes);
        final calories =
            weeklyWorkouts.fold<int>(0, (sum, w) => sum + w.caloriesBurned);

        return Row(
          children: [
            Expanded(
              child: _MiniStat(
                Icons.local_fire_department_outlined,
                AppColors.lime,
                AppColors.limeDark,
                '$sessions',
                'Séances',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                Icons.access_time_rounded,
                AppColors.purple,
                AppColors.purpleDark,
                _formatMinutes(minutes),
                'Temps actif',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStat(
                Icons.bar_chart_rounded,
                AppColors.orange,
                AppColors.orangeDark,
                _formatNumber(calories),
                'Kcal brûlées',
              ),
            ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // PROCHAINE SÉANCE (CHRONOLOGIQUE LA PLUS PROCHE DANS LE FUTUR)
  // --------------------------------------------------

  Widget _nextSession(
    BuildContext context,
    ReservationRepository reservationRepo,
    SessionRepository sessionRepo,
    String uid,
  ) {
    final now = DateTime.now();

    // 1. D'abord vérifier si l'adhérent a une réservation future confirmée
    return StreamBuilder<List<Reservation>>(
      stream: reservationRepo.getUserReservationsStream(uid),
      builder: (context, resSnapshot) {
        final reservations = (resSnapshot.data ?? [])
            .where((r) => r.isReserved && r.startAt.isAfter(now))
            .toList();

        reservations.sort((a, b) => a.startAt.compareTo(b.startAt));

        if (reservations.isNotEmpty) {
          final next = reservations.first;
          final startAt = next.startAt;
          final initials = _initials(next.coachName);

          return AppCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyReservationsScreen(),
                ),
              );
            },
            child: Row(
              children: [
                DateBadge(
                  month: _monthName(startAt.month),
                  day: startAt.day,
                  size: 60,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _sameDay(startAt, now) ? "AUJOURD'HUI" : 'À VENIR',
                            style: AppText.eyebrow(),
                          ),
                          const SizedBox(width: 8),
                          const PillBadge('RÉSERVÉ',
                              dot: true, color: AppColors.lime),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next.sessionTitle,
                        style: AppText.body(
                          16,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_twoDigits(startAt.hour)}:${_twoDigits(startAt.minute)}'
                        ' · ${next.durationMinutes} min'
                        '${next.studio.isNotEmpty ? ' · ${next.studio}' : ''}',
                        style: AppText.body(
                          11.5,
                          color: AppColors.muted,
                        ),
                      ),
                      if (next.coachName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            AvatarCircle(initials, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'avec ${next.coachName}',
                                style: AppText.body(
                                  10.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface2,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          );
        }

        // 2. Si aucune réservation, afficher la toute prochaine séance disponible au club
        return StreamBuilder<Session?>(
          stream: sessionRepo.getNearestUpcomingSessionStream(),
          builder: (context, sessSnapshot) {
            final nextSession = sessSnapshot.data;

            if (nextSession == null) {
              return AppCard(
                child: Text(
                  'Aucune séance à venir pour le moment.',
                  style: AppText.body(
                    13,
                    color: AppColors.muted,
                  ),
                ),
              );
            }

            final startAt = nextSession.startAt;
            final initials = _initials(nextSession.coach);

            return AppCard(
              child: Row(
                children: [
                  DateBadge(
                    month: _monthName(startAt.month),
                    day: startAt.day,
                    size: 60,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sameDay(startAt, now)
                              ? "AUJOURD'HUI"
                              : 'PROCHAINE AU CLUB',
                          style: AppText.eyebrow(color: AppColors.lime),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextSession.title,
                          style: AppText.body(
                            16,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_twoDigits(startAt.hour)}:${_twoDigits(startAt.minute)}'
                          ' · ${nextSession.duration} min'
                          '${nextSession.studio.isNotEmpty ? ' · ${nextSession.studio}' : ''}',
                          style: AppText.body(
                            11.5,
                            color: AppColors.muted,
                          ),
                        ),
                        if (nextSession.coach.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              AvatarCircle(initials, size: 20),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'avec ${nextSession.coach}',
                                  style: AppText.body(
                                    10.5,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      'JAN',
      'FÉV',
      'MAR',
      'AVR',
      'MAI',
      'JUN',
      'JUL',
      'AOÛ',
      'SEP',
      'OCT',
      'NOV',
      'DÉC'
    ];
    return months[month - 1];
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'C';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatMinutes(int minutes) {
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    if (hours == 0) return '${remaining}m';
    if (remaining == 0) return '${hours}h';
    return '${hours}h $remaining';
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String value;
  final String label;

  const _MiniStat(
    this.icon,
    this.color,
    this.bg,
    this.value,
    this.label,
  );

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(
            icon: icon,
            color: color,
            bg: bg,
            size: 36,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: AppText.title(22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.body(
              10.5,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
