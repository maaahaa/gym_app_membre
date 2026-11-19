import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/models.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/reservation_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../services/auth_service.dart';
import 'subscriptions_screen.dart';

/// Gabarit commun des sous-écrans : bouton retour + titre.
class SubScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const SubScaffold({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title, style: AppText.title(22)),
      ),
      body: SafeArea(child: child),
    );
  }
}

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  final UserRepository _userRepo = UserRepository();
  final AuthService _authService = AuthService();

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté.');
      }

      final appUser = await _userRepo.getUser(user.uid);
      if (appUser != null) {
        _name.text = appUser.name;
        _email.text = appUser.email;
        _phone.text = appUser.phone;
      } else {
        _email.text = user.email ?? '';
      }
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Impossible de charger vos informations.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveUserData() async {
    if (!_key.currentState!.validate()) return;
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté.');
      }

      await _userRepo.updateUser(user.uid, {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
      });

      if (!mounted) return;

      showSnack(context, 'Informations mises à jour.');
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      showSnack(context, 'Une erreur est survenue.');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SubScaffold(
      title: 'Informations personnelles',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _key,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Nom complet',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().length < 3 ? 'Nom trop court' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Adresse e-mail',
                    ),
                    validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch((v ?? '').trim())
                        ? null
                        : "Format d'e-mail invalide",
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                    ),
                    validator: (v) =>
                        RegExp(r'^\d{8}$').hasMatch((v ?? '').trim())
                            ? null
                            : 'Numéro à 8 chiffres',
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    _saving ? 'Enregistrement...' : 'Enregistrer',
                    onPressed: _saving ? null : _saveUserData,
                  ),
                ],
              ),
            ),
    );
  }
}

class MyReservationsScreen extends StatelessWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final reservationRepo = ReservationRepository();
    final user = authService.currentUser;

    return SubScaffold(
      title: 'Mes réservations',
      child: user == null
          ? Center(
              child: Text(
                'Connectez-vous pour voir vos réservations.',
                style: AppText.body(14, color: AppColors.muted),
              ),
            )
          : StreamBuilder<List<Reservation>>(
              stream: reservationRepo.getUserReservationsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Impossible de charger les réservations.',
                      style: AppText.body(14, color: AppColors.muted),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reservations =
                    (snapshot.data ?? []).where((r) => r.isReserved).toList();

                if (reservations.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune réservation.',
                      style: AppText.body(14, color: AppColors.muted),
                    ),
                  );
                }

                reservations.sort((a, b) => a.startAt.compareTo(b.startAt));

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: reservations.map((res) {
                    final date = res.startAt;
                    final timeLabel = '${date.hour.toString().padLeft(2, '0')}:'
                        '${date.minute.toString().padLeft(2, '0')}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AppCard(
                        child: Row(
                          children: [
                            DateBadge(
                              month: _monthName(date.month),
                              day: date.day,
                              size: 54,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    res.sessionTitle,
                                    style: AppText.body(
                                      14.5,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$timeLabel · ${res.durationMinutes} min · ${res.studio}',
                                    style: AppText.body(
                                      11,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await reservationRepo.cancelReservation(
                                      user.uid, res.sessionId);
                                  if (context.mounted) {
                                    showSnack(context, 'Réservation annulée');
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    showSnack(context,
                                        'Impossible d’annuler la réservation.');
                                  }
                                }
                              },
                              child: Text(
                                'Annuler',
                                style: AppText.body(
                                  12,
                                  color: AppColors.red,
                                  weight: FontWeight.w800,
                                ),
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

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final AuthService _authService = AuthService();
  final NotificationRepository _notifRepo = NotificationRepository();
  bool _markingAll = false;
  final Set<String> _locallyReadIds = {};

  /// Marque une notification comme lue lors du tap.
  Future<void> _onTapNotification(AppNotification n, String uid) async {
    final isRead = n.isRead || _locallyReadIds.contains(n.id);
    if (!isRead) {
      setState(() => _locallyReadIds.add(n.id));
      await _notifRepo.markAsRead(n.id, uid: uid);
    }
    if (!mounted) return;
    switch (n.type) {
      case 'reservation':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyReservationsScreen(),
          ),
        );
        break;
      case 'subscription':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SubscriptionsScreen(),
          ),
        );
        break;
    }
  }

  /// Marque TOUTES les notifications comme lues avec retour visuel immédiat.
  Future<void> _markAllRead(String uid, List<AppNotification> list) async {
    if (_markingAll) return;
    setState(() {
      _markingAll = true;
      _locallyReadIds.addAll(list.map((n) => n.id));
    });

    try {
      await _notifRepo.markAllAsRead(uid);
      if (mounted) {
        showSnack(
            context, 'Toutes les notifications ont été marquées comme lues.');
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Erreur lors de la mise à jour.');
      }
    } finally {
      if (mounted) {
        setState(() => _markingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return SubScaffold(
      title: 'Notifications',
      child: user == null
          ? Center(
              child: Text(
                'Connectez-vous pour consulter vos notifications.',
                style: AppText.body(13, color: AppColors.muted),
              ),
            )
          : StreamBuilder<List<AppNotification>>(
              stream: _notifRepo.getUserNotificationsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Impossible de charger les notifications.',
                      style: AppText.body(13, color: AppColors.muted),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data ?? [];
                final unreadCount = notifications.where((n) {
                  final isRead = n.isRead || _locallyReadIds.contains(n.id);
                  return !isRead;
                }).length;

                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucune notification.',
                        style: AppText.body(13, color: AppColors.muted),
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // En-tête avec compteur non-lues + bouton tout marquer
                    if (unreadCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Text(
                              '$unreadCount non lue${unreadCount > 1 ? 's' : ''}',
                              style: AppText.body(12.5,
                                  color: AppColors.lime,
                                  weight: FontWeight.w700),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _markingAll
                                  ? null
                                  : () => _markAllRead(user.uid, notifications),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_markingAll) ...[
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.lime,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    'Tout marquer comme lu',
                                    style: AppText.body(11.5,
                                        color: _markingAll
                                            ? AppColors.muted
                                            : AppColors.lime,
                                        weight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Liste des notifications
                    ...notifications.map((n) {
                      final isRead = n.isRead || _locallyReadIds.contains(n.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () => _onTapNotification(n, user.uid),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isRead
                                  ? AppColors.surface
                                  : AppColors.limeDark.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isRead
                                    ? AppColors.border
                                    : AppColors.lime.withValues(alpha: 0.4),
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                IconBox(icon: n.icon),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: AppText.body(13.5,
                                                  weight: FontWeight.w700),
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.lime,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.message,
                                        style: AppText.body(11.5,
                                            color: AppColors.muted),
                                      ),
                                      if (n.createdAt != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          formatDate(n.createdAt!),
                                          style: AppText.body(10,
                                              color: AppColors.lime,
                                              weight: FontWeight.w700),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final workoutRepo = WorkoutRepository();
    final user = authService.currentUser;

    return SubScaffold(
      title: "Historique d'activités",
      child: user == null
          ? Center(
              child: Text(
                'Connectez-vous pour voir votre historique.',
                style: AppText.body(13, color: AppColors.muted),
              ),
            )
          : StreamBuilder<List<Workout>>(
              stream: workoutRepo.getUserWorkoutsStream(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final workouts = snapshot.data ?? [];

                if (workouts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Aucun historique d'activité.",
                        style: AppText.body(13, color: AppColors.muted),
                      ),
                    ),
                  );
                }

                workouts.sort((a, b) => b.completedAt.compareTo(a.completedAt));

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: workouts
                      .map((w) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              child: Row(
                                children: [
                                  const IconBox(icon: Icons.history_rounded),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.sessionTitle,
                                          style: AppText.body(14,
                                              weight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${w.durationMinutes} min · ${w.caloriesBurned} kcal',
                                          style: AppText.body(11,
                                              color: AppColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatDate(w.completedAt),
                                    style: AppText.body(10.5,
                                        color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
    );
  }
}
