import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/models.dart';
import '../../repositories/coach_repository.dart';
import '../../repositories/reservation_repository.dart';
import '../../repositories/session_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import 'profile_sub_screens.dart';

/// Écran listant tous les coachs de la salle (rôle == 'coach', isActive == true).

class CoachesScreen extends StatelessWidget {
  const CoachesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coachRepo = CoachRepository();
    final userRepo = UserRepository();
    final authService = AuthService();
    final currentUserId = authService.currentUser?.uid ?? '';

    return SubScaffold(
      title: 'Nos coachs',
      child: StreamBuilder<AppUser?>(
        stream: userRepo.getUserStream(currentUserId),
        builder: (context, userSnapshot) {
          final currentUser = userSnapshot.data;
          final myCoachId = currentUser?.coachId;

          return StreamBuilder<List<Coach>>(
            stream: coachRepo.getCoachesStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Impossible de charger les coachs.',
                    style: AppText.body(13, color: AppColors.muted),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final coaches = snapshot.data ?? [];

              if (coaches.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aucun coach disponible pour le moment.',
                      style: AppText.body(13, color: AppColors.muted),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: coaches.map((c) {
                  final isMyCoach = c.id == myCoachId;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      borderColor: isMyCoach
                          ? AppColors.lime.withValues(alpha: 0.5)
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CoachDetailScreen(coach: c),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Photo ou avatar du coach
                          c.photoUrl != null && c.photoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    c.photoUrl!,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        AvatarCircle(c.initials, size: 52),
                                  ),
                                )
                              : AvatarCircle(c.initials, size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        style: AppText.body(15,
                                            weight: FontWeight.w700),
                                      ),
                                    ),
                                    if (isMyCoach)
                                      const PillBadge('MON COACH', dot: false),
                                  ],
                                ),
                                if (c.specialties.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    c.specialties.join(' · '),
                                    style: AppText.body(11,
                                        color: AppColors.muted),
                                  ),
                                ],
                                if (c.experience != null &&
                                    c.experience!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Expérience : ${c.experience}',
                                    style: AppText.body(10.5,
                                        color: AppColors.muted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}

/// Écran de détail d'un coach : infos, spécialités, séances proposées.
/// Pas de bouton "Choisir comme mon coach".
class CoachDetailScreen extends StatefulWidget {
  final Coach coach;
  const CoachDetailScreen({super.key, required this.coach});

  @override
  State<CoachDetailScreen> createState() => _CoachDetailScreenState();
}

class _CoachDetailScreenState extends State<CoachDetailScreen> {
  final AuthService _authService = AuthService();
  final UserRepository _userRepo = UserRepository();
  final SessionRepository _sessionRepo = SessionRepository();
  final ReservationRepository _reservationRepo = ReservationRepository();
  final CoachRepository _coachRepo = CoachRepository();
  StreamSubscription<Coach?>? _coachSubscription;
  Coach? _liveCoach;

  final Set<String> _processingSessions = {};

  @override
  void initState() {
    super.initState();
    _liveCoach = widget.coach;
    _coachSubscription =
        _coachRepo.getCoachStream(widget.coach.id).listen((coach) {
      if (mounted && coach != null) {
        setState(() => _liveCoach = coach);
      }
    });
  }

  @override
  void dispose() {
    _coachSubscription?.cancel();
    super.dispose();
  }

  Future<void> _reserve(
    Session session,
    String memberId,
    String memberName,
    String memberEmail,
    bool isReserved,
  ) async {
    final sessionId = session.id;
    if (_processingSessions.contains(sessionId)) return;

    setState(() => _processingSessions.add(sessionId));

    try {
      if (isReserved) {
        await _reservationRepo.cancelReservation(memberId, sessionId);
        if (mounted) showSnack(context, 'Réservation annulée.');
      } else {
        await _reservationRepo.reserveSession(
          memberId: memberId,
          memberName: memberName,
          memberEmail: memberEmail,
          session: session,
        );
        if (mounted) {
          showSnack(context, 'Réservation confirmée pour ${session.title}.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('ALREADY_RESERVED')) {
        showSnack(context, 'Tu es déjà inscrit(e) à cette séance.');
      } else if (msg.contains('SESSION_FULL')) {
        showSnack(context, 'Cette séance est complète.');
      } else if (msg.contains('SESSION_PASSED')) {
        showSnack(context, 'Cette séance est déjà passée.');
      } else if (msg.contains('SESSION_NOT_APPROVED')) {
        showSnack(context, 'Cette séance n\u2019est pas encore validée.');
      } else {
        showSnack(context, 'Une erreur est survenue lors de la réservation.');
      }
    } finally {
      if (mounted) setState(() => _processingSessions.remove(sessionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final currentUserId = currentUser?.uid ?? '';
    final coach = _liveCoach ?? widget.coach;

    return SubScaffold(
      title: coach.name,
      child: StreamBuilder<AppUser?>(
        stream: _userRepo.getUserStream(currentUserId),
        builder: (context, userSnapshot) {
          final memberProfile = userSnapshot.data;
          final memberName = memberProfile?.name ?? 'Membre';

          return StreamBuilder<List<Reservation>>(
            stream: _reservationRepo.getUserReservationsStream(currentUserId),
            builder: (context, resSnapshot) {
              final reservedSessionIds = <String>{};
              for (final r in resSnapshot.data ?? []) {
                if (r.isReserved) reservedSessionIds.add(r.sessionId);
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Photo ou avatar du coach
                  Center(
                    child: coach.photoUrl != null && coach.photoUrl!.isNotEmpty
                        ? ClipOval(
                            child: Image.network(
                              coach.photoUrl!,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  AvatarCircle(coach.initials, size: 88),
                            ),
                          )
                        : AvatarCircle(coach.initials, size: 88),
                  ),
                  const SizedBox(height: 16),
                  if (coach.bio.isNotEmpty)
                    Text(
                      coach.bio,
                      textAlign: TextAlign.center,
                      style: AppText.body(12.5, color: AppColors.muted),
                    ),
                  const SizedBox(height: 12),
                  if (coach.experience != null && coach.experience!.isNotEmpty)
                    Center(
                      child: Text(
                        'Expérience : ${coach.experience}',
                        style: AppText.body(11.5,
                            color: AppColors.lime, weight: FontWeight.w700),
                      ),
                    ),
                  if (coach.email.isNotEmpty || coach.phone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    if (coach.email.isNotEmpty)
                      Center(
                        child: Text(
                          coach.email,
                          style: AppText.body(11.5, color: AppColors.muted),
                        ),
                      ),
                    if (coach.phone.isNotEmpty)
                      Center(
                        child: Text(
                          coach.phone,
                          style: AppText.body(11.5, color: AppColors.muted),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  if (coach.specialties.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: coach.specialties
                          .map((s) => PillBadge(s, dot: false))
                          .toList(),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    'Séances proposées',
                    style: AppText.body(18, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),

                  // Liste des séances de ce coach
                  StreamBuilder<List<Session>>(
                    stream: _sessionRepo.getSessionsByCoachStream(coach.id),
                    builder: (context, sessionSnapshot) {
                      if (sessionSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final now = DateTime.now();
                      final sessions = (sessionSnapshot.data ?? [])
                          .where((s) => s.active && s.startAt.isAfter(now))
                          .toList();

                      if (sessions.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Aucune séance proposée par ce coach pour le moment.',
                            style: AppText.body(12, color: AppColors.muted),
                          ),
                        );
                      }

                      return Column(
                        children: sessions.map((s) {
                          final isReserved =
                              reservedSessionIds.contains(s.id) ||
                                  s.isMemberEnrolled(currentUserId);
                          final spots = s.spotsLeft;
                          final processing = _processingSessions.contains(s.id);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  DateBadge(
                                    month: _monthName(s.startAt.month),
                                    day: s.day,
                                    size: 52,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.title,
                                          style: AppText.body(14,
                                              weight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        if (s.category.isNotEmpty)
                                          Text(
                                            s.category,
                                            style: AppText.body(10.5,
                                                color: s.color,
                                                weight: FontWeight.w700),
                                          ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${s.time} · ${s.duration} min · ${s.studio}',
                                          style: AppText.body(11,
                                              color: AppColors.muted),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$spots place(s) disponible(s) sur ${s.capacity}',
                                          style: AppText.body(10.5,
                                              color: spots <= 3
                                                  ? AppColors.orange
                                                  : AppColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  processing
                                      ? const SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : isReserved
                                          ? OutlinedButton(
                                              onPressed: () => _reserve(
                                                s,
                                                currentUserId,
                                                memberName,
                                                memberProfile?.email ??
                                                    currentUser?.email ??
                                                    '',
                                                true,
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.lime,
                                                side: const BorderSide(
                                                    color: AppColors.lime),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 8),
                                              ),
                                              child: const Text('Inscrit(e)'),
                                            )
                                          : PrimaryButton(
                                              'Réserver',
                                              small: true,
                                              expand: false,
                                              onPressed: (spots <= 0 ||
                                                      currentUserId.isEmpty)
                                                  ? null
                                                  : () => _reserve(
                                                        s,
                                                        currentUserId,
                                                        memberName,
                                                        memberProfile?.email ??
                                                            currentUser
                                                                ?.email ??
                                                            '',
                                                        false,
                                                      ),
                                            ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static String _monthName(int month) {
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
}
