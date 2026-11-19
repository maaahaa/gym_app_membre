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
import '../../repositories/subscription_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import 'coaches_screen.dart';

class MemberSessions extends StatefulWidget {
  const MemberSessions({super.key});

  @override
  State<MemberSessions> createState() => _MemberSessionsState();
}

class _MemberSessionsState extends State<MemberSessions> {
  String _filter = 'Tous';
  late DateTime _selectedDate;
  final Set<String> _processing = {};
  Timer? _autoRefreshTimer;

  final SessionRepository _sessionRepo = SessionRepository();
  final ReservationRepository _reservationRepo = ReservationRepository();
  final SubscriptionRepository _subRepo = SubscriptionRepository();
  final CoachRepository _coachRepo = CoachRepository();
  final UserRepository _userRepo = UserRepository();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();

    // Actualisation périodique automatique toutes les 30 secondes pour
    // éliminer en temps réel les séances qui viennent d'expirer ou de commencer
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  List<DateTime> get _weekDates {
    final monday = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    ).subtract(Duration(days: _selectedDate.weekday - 1));

    return List.generate(
      7,
      (index) => monday.add(Duration(days: index)),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayName(int weekday) {
    const names = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];
    return names[weekday - 1];
  }

  Future<void> _onAction(
    Session session,
    String memberId,
    String memberName,
    String memberEmail,
    bool reserved,
  ) async {
    if (memberId.isEmpty) {
      showSnack(context, 'Connectez-vous pour réserver une séance.');
      return;
    }

    final sessionId = session.id;
    if (_processing.contains(sessionId)) return;

    if (reserved) {
      // ── Annulation ──────────────────────────────────────────────────────────
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Annuler la réservation ?',
            style: AppText.title(20),
          ),
          content: Text(
            '${session.title} · ${session.time}',
            style: AppText.body(
              13,
              color: AppColors.muted,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Garder',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Annuler la réservation',
                style: TextStyle(color: AppColors.red),
              ),
            ),
          ],
        ),
      );

      if (ok != true || !mounted) return;

      setState(() => _processing.add(sessionId));
      try {
        await _reservationRepo.cancelReservation(memberId, sessionId);
        if (mounted) showSnack(context, 'Réservation annulée.');
      } catch (_) {
        if (mounted) {
          showSnack(context, 'Une erreur est survenue lors de l\u2019annulation.');
        }
      } finally {
        if (mounted) setState(() => _processing.remove(sessionId));
      }
      return;
    }

    // ── Nouvelle réservation : vérification de l'abonnement ─────────────────
    setState(() => _processing.add(sessionId));

    try {
      // 1. Charger l'abonnement actif du membre
      final subscription =
          await _subRepo.getUserSubscriptionStream(memberId).first;

      if (!mounted) return;

      // 2. Déterminer si la séance est couverte par l'abonnement
      final bool isCovered = _isSessionCoveredBySubscription(
        subscription,
        session,
      );

      if (!isCovered) {
        // 3. La séance est HORS abonnement → proposer le paiement à la séance
        setState(() => _processing.remove(sessionId));

        final plans = await _subRepo.getSubscriptionPlansStream().first;
        if (!mounted) return;

        // Chercher les forfaits par séance disponibles pour afficher les prix
        final perSessionPlans =
            plans.where((p) => p.isPerSession && p.isActive).toList();

        final confirmed = await _showPayPerSessionDialog(
          session: session,
          subscription: subscription,
          perSessionPlans: perSessionPlans,
        );
        if (confirmed != true || !mounted) return;

        setState(() => _processing.add(sessionId));
      } else {
        // 4. Couverte par l'abonnement → confirmation simple
        final confirmed = await _showSubscriptionConfirmDialog(
          session: session,
          subscription: subscription,
        );
        if (confirmed != true || !mounted) {
          setState(() => _processing.remove(sessionId));
          return;
        }
      }

      // 5. Procéder à la réservation
      await _reservationRepo.reserveSession(
        memberId: memberId,
        memberName: memberName,
        memberEmail: memberEmail,
        session: session,
        paymentType: isCovered ? 'subscription' : 'singleSeance',
      );

      if (mounted) {
        showSnack(context, 'Réservation confirmée pour ${session.title}.');
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();
      if (message.contains('ALREADY_RESERVED')) {
        showSnack(context, 'Tu es déjà inscrit(e) à cette séance.');
      } else if (message.contains('SESSION_FULL')) {
        showSnack(context, 'Cette séance est complète.');
      } else if (message.contains('SESSION_PASSED')) {
        showSnack(context, 'Cette séance est déjà passée.');
      } else if (message.contains('SESSION_NOT_APPROVED')) {
        showSnack(context, 'Cette séance n\u2019est pas encore validée.');
      } else {
        showSnack(context, 'Une erreur est survenue lors de la réservation.');
      }
    } finally {
      if (mounted) {
        setState(() => _processing.remove(sessionId));
      }
    }
  }

  /// Vérifie si la séance est couverte par l'abonnement actif du membre.
  ///
  /// - Abonnement **global** (accès illimité) → toujours couvert.
  /// - Abonnement **par séance** (workout / sessionsCount) → couvert seulement
  ///   si des séances restantes existent ET si la catégorie correspond
  ///   (targetActivity vide = toutes catégories).
  /// - Pas d'abonnement actif → non couvert.
  bool _isSessionCoveredBySubscription(
    Subscription? subscription,
    Session session,
  ) {
    if (subscription == null || !subscription.isActive) return false;

    // Abonnement global (illimité)
    if (!subscription.isPerSession) return true;

    // Abonnement par séance
    final sessionsLeft = subscription.sessionsLeft;
    if (sessionsLeft != null && sessionsLeft <= 0) return false;

    // Vérification de l'activité ciblée (si renseignée)
    final target = subscription.targetActivity;
    if (target != null && target.isNotEmpty) {
      final targetLower = target.toLowerCase().trim();
      final categoryLower = session.category.toLowerCase().trim();
      final titleLower = session.title.toLowerCase().trim();
      if (!categoryLower.contains(targetLower) &&
          !titleLower.contains(targetLower)) {
        return false;
      }
    }

    return true;
  }

  /// Dialogue de confirmation quand la séance est couverte par l'abonnement.
  Future<bool?> _showSubscriptionConfirmDialog({
    required Session session,
    required Subscription? subscription,
  }) {
    final subLabel = subscription != null
        ? subscription.planName
        : 'Abonnement actif';
    final sessionsInfo = subscription?.sessionsLeft != null
        ? '\nSéances restantes : ${subscription!.sessionsLeft}'
        : '';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text('Confirmer la réservation ?', style: AppText.title(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${session.title} · ${session.time}',
              style: AppText.body(14, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.lime, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Incluse dans : $subLabel$sessionsInfo',
                    style: AppText.body(12, color: AppColors.lime),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Réserver',
                style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );
  }

  /// Dialogue affiché quand la séance est HORS abonnement.
  /// Montre les prix des forfaits par séance disponibles et demande
  /// au membre de confirmer le paiement à la séance.
  Future<bool?> _showPayPerSessionDialog({
    required Session session,
    required Subscription? subscription,
    required List<SubscriptionPlan> perSessionPlans,
  }) {
    // Raison explicite du refus de couverture
    String reason;
    if (subscription == null || !subscription.isActive) {
      reason = 'Tu n\u2019as pas d\u2019abonnement actif.';
    } else if (subscription.isPerSession &&
        (subscription.sessionsLeft ?? 1) <= 0) {
      reason = 'Tu n\u2019as plus de séances disponibles dans ton abonnement.';
    } else if (subscription.targetActivity != null &&
        subscription.targetActivity!.isNotEmpty) {
      reason =
          'Ton abonnement « ${subscription.planName} » couvre uniquement '
          'les cours de type « ${subscription.targetActivity} ».';
    } else {
      reason = 'Cette séance n\u2019est pas couverte par ton abonnement actuel.';
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.orange, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Séance hors abonnement', style: AppText.title(18)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.title} · ${session.time}',
                style: AppText.body(14, weight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                reason,
                style: AppText.body(12.5, color: AppColors.orange),
              ),
              const SizedBox(height: 14),
              Text(
                'Pour réserver cette séance, tu peux payer à l\u2019unité.',
                style: AppText.body(12.5, color: AppColors.muted),
              ),
              if (perSessionPlans.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Tarifs disponibles :',
                  style: AppText.body(12,
                      weight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 8),
                ...perSessionPlans.map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 6, color: AppColors.lime),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.name,
                            style: AppText.body(12),
                          ),
                        ),
                        Text(
                          '${p.price} DT'
                          '${p.sessionsCount != null ? ' / ${p.sessionsCount} séance${p.sessionsCount! > 1 ? 's' : ''}' : ' / séance'}',
                          style: AppText.body(12,
                              weight: FontWeight.w800,
                              color: AppColors.lime),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'En confirmant, le paiement sera enregistré comme paiement à la séance.',
                style: AppText.body(11, color: AppColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Payer et réserver',
                style: TextStyle(color: AppColors.orange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final currentUserId = user?.uid ?? '';
    final now = DateTime.now();

    return StreamBuilder<AppUser?>(
      stream: _userRepo.getUserStream(currentUserId),
      builder: (context, userSnapshot) {
        final appUser = userSnapshot.data;
        final memberName = appUser?.name ?? 'Membre';
        final memberEmail = appUser?.email ?? user?.email ?? '';

        // Toutes les séances depuis Firestore
        return StreamBuilder<List<Session>>(
          stream: _sessionRepo.getSessionsStream(),
          builder: (context, sessionsSnapshot) {
            if (sessionsSnapshot.hasError) {
              return Center(
                child: Text(
                  'Impossible de charger les séances.',
                  style: AppText.body(
                    13,
                    color: AppColors.muted,
                  ),
                ),
              );
            }

            if (sessionsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final allSessions = sessionsSnapshot.data ?? [];

            // Catégories réelles présentes dans les séances actives de Firestore
            final dynamicCategories = <String>{'Tous'};
            for (final s in allSessions) {
              if (s.category.isNotEmpty) dynamicCategories.add(s.category);
            }
            final filterList = dynamicCategories.toList();

            if (!filterList.contains(_filter)) {
              _filter = 'Tous';
            }

            return StreamBuilder<List<Reservation>>(
              stream: currentUserId.isEmpty
                  ? Stream.value([])
                  : _reservationRepo.getUserReservationsStream(currentUserId),
              builder: (context, reservationsSnapshot) {
                final reservedIds = <String>{};
                for (final res in reservationsSnapshot.data ?? []) {
                  if (res.isReserved) {
                    reservedIds.add(res.sessionId);
                  }
                }

                // Filtrage strict :
                // 1. Séance active et NON annulée
                // 2. Jour sélectionné exact
                // 3. Date et heure STRICTEMENT dans le futur (pas passée ni terminée)
                // 4. Places restantes > 0 (si complète, exclue sauf si l'adhérent y est déjà inscrit)
                // 5. Filtre catégorie
                final filteredList = allSessions.where((s) {
                  if (!s.active || s.isCancelled) return false;
                  if (!_sameDay(s.startAt, _selectedDate)) return false;
                  if (!s.startAt.isAfter(now) || s.isFinished) return false;

                  final isUserEnrolled = reservedIds.contains(s.id) ||
                      s.isMemberEnrolled(currentUserId);
                  if (s.spotsLeft <= 0 && !isUserEnrolled) return false;

                  if (_filter != 'Tous' && s.category != _filter) return false;
                  return true;
                }).toList();

                filteredList.sort((a, b) => a.startAt.compareTo(b.startAt));

                final isPastSelectedDay = _selectedDate
                    .isBefore(DateTime(now.year, now.month, now.day));

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Text(
                      'TON PLANNING',
                      style: AppText.eyebrow(),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Séances disponibles',
                      style: AppText.title(32),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Trouve les cours à venir et réserve ta place.',
                      style: AppText.body(
                        12.5,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Filtres dynamiques de catégories
                    if (filterList.length > 1)
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filterList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final filter = filterList[i];
                            final active = filter == _filter;

                            return GestureDetector(
                              onTap: () {
                                setState(() => _filter = filter);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.lime
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.lime
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  filter,
                                  style: AppText.body(
                                    11.5,
                                    color: active
                                        ? Colors.black
                                        : AppColors.muted,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 14),

                    // Sélecteur de jour de la semaine
                    Row(
                      children: _weekDates.map((date) {
                        final active = _sameDay(date, _selectedDate);
                        final isDayInPast = date
                            .isBefore(DateTime(now.year, now.month, now.day));

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedDate = date);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: active
                                    ? AppColors.limeDark
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: active
                                      ? AppColors.lime
                                      : AppColors.border,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _weekdayName(date.weekday),
                                    style: AppText.body(
                                      9,
                                      color: active
                                          ? AppColors.lime
                                          : isDayInPast
                                              ? AppColors.muted.withValues(alpha: 0.5)
                                              : AppColors.muted,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${date.day}',
                                    style: AppText.title(
                                      20,
                                      color: active
                                          ? AppColors.lime
                                          : isDayInPast
                                              ? Colors.white38
                                              : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 22),

                    Text(
                      '${filteredList.length} séance${filteredList.length > 1 ? 's' : ''} disponible${filteredList.length > 1 ? 's' : ''}',
                      style: AppText.body(
                        18,
                        weight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 14),

                    if (filteredList.isEmpty)
                      AppCard(
                        child: Text(
                          isPastSelectedDay
                              ? 'Cette journée est déjà passée. Choisis une date future pour voir les séances disponibles.'
                              : _sameDay(_selectedDate, now)
                                  ? 'Plus aucune séance à venir aujourd\u2019hui dans cette catégorie.'
                                  : 'Aucune séance programmée pour cette date.',
                          style: AppText.body(
                            13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),

                    ...filteredList.map(
                      (s) => _sessionCard(
                        s,
                        currentUserId,
                        memberName,
                        memberEmail,
                        reservedIds.contains(s.id) ||
                            s.isMemberEnrolled(currentUserId),
                      ),
                    ),

                    const SizedBox(height: 12),
                    _coachOfWeek(context),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _sessionCard(
    Session session,
    String memberId,
    String memberName,
    String memberEmail,
    bool reserved,
  ) {
    final spots = session.spotsLeft;
    final color = session.color;
    final processing = _processing.contains(session.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: color),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      session.time,
                      style: AppText.title(20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.duration} min',
                      style: AppText.body(
                        10.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: AppText.body(
                          15,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (session.category.isNotEmpty)
                        Text(
                          session.category,
                          style: AppText.body(
                            10.5,
                            color: color,
                            weight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Text(
                        'avec ${session.coach}'
                        '${session.studio.isNotEmpty ? ' · ${session.studio}' : ''}',
                        style: AppText.body(
                          11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: spots <= 3
                                  ? AppColors.orange
                                  : AppColors.lime,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '$spots place${spots > 1 ? 's' : ''} restante${spots > 1 ? 's' : ''}',
                              style: AppText.body(
                                10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: processing
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : reserved
                        ? InkWell(
                            onTap: () => _onAction(
                              session,
                              memberId,
                              memberName,
                              memberEmail,
                              true,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.limeDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: AppColors.lime,
                              ),
                            ),
                          )
                        : PrimaryButton(
                            'Réserver',
                            small: true,
                            expand: false,
                            onPressed: (spots <= 0 || memberId.isEmpty)
                                ? null
                                : () => _onAction(
                                      session,
                                      memberId,
                                      memberName,
                                      memberEmail,
                                      false,
                                    ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Affiche le coach à la une parmi les coachs de type 'gym' de la salle.
  Widget _coachOfWeek(BuildContext context) {
    return StreamBuilder<List<Coach>>(
      stream: _coachRepo.getCoachesStream(),
      builder: (context, snapshot) {
        final coaches = snapshot.data ?? [];
        if (coaches.isEmpty) return const SizedBox.shrink();

        final coach = coaches.first;

        return AppCard(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF24203A),
              Color(0xFF14150F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CoachesScreen(),
            ),
          ),
          child: Row(
            children: [
              coach.photoUrl != null && coach.photoUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        coach.photoUrl!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            AvatarCircle(coach.initials, size: 52),
                      ),
                    )
                  : AvatarCircle(coach.initials, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COACH DU CLUB',
                      style: AppText.eyebrow(
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coach.name,
                      style: AppText.body(
                        16,
                        weight: FontWeight.w700,
                      ),
                    ),
                    if (coach.specialties.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        coach.specialties.join(' · '),
                        style: AppText.body(
                          11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
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
}
