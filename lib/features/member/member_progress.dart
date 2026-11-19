import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/ring_progress.dart';
import '../../models/models.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../services/auth_service.dart';

class MemberProgress extends StatefulWidget {
  const MemberProgress({super.key});

  @override
  State<MemberProgress> createState() => _MemberProgressState();
}

class _MemberProgressState extends State<MemberProgress> {
  final AuthService _authService = AuthService();
  final UserRepository _userRepo = UserRepository();
  final WorkoutRepository _workoutRepo = WorkoutRepository();

  void _showAddPerformanceDialog(BuildContext context, String uid) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: 'Musculation');
    final durationCtrl = TextEditingController(text: '45');
    final caloriesCtrl = TextEditingController(text: '350');
    final volumeCtrl = TextEditingController(text: '500');
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Saisir une performance', style: AppText.title(22)),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la séance / Activité',
                        prefixIcon: Icon(Icons.fitness_center_rounded),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Titre obligatoire' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: durationCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Durée (min)',
                              prefixIcon: Icon(Icons.timer_outlined),
                            ),
                            validator: (v) => int.tryParse(v ?? '') == null
                                ? 'Invalide'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: caloriesCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Calories (kcal)',
                              prefixIcon: Icon(Icons.local_fire_department_outlined),
                            ),
                            validator: (v) => int.tryParse(v ?? '') == null
                                ? 'Invalide'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: volumeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Volume total soulevé (kg)',
                        prefixIcon: Icon(Icons.bar_chart_rounded),
                      ),
                      validator: (v) =>
                          int.tryParse(v ?? '') == null ? 'Invalide' : null,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      saving ? 'Enregistrement...' : 'Ajouter la performance',
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => saving = true);

                              try {
                                await _workoutRepo.addWorkout(
                                  uid: uid,
                                  sessionTitle: titleCtrl.text.trim(),
                                  durationMinutes: int.parse(durationCtrl.text),
                                  caloriesBurned: int.parse(caloriesCtrl.text),
                                  volumeKg: int.parse(volumeCtrl.text),
                                );

                                if (!dialogCtx.mounted) return;
                                Navigator.pop(dialogCtx);

                                if (!mounted) return;
                                showSnack(context, 'Performance enregistrée !');
                              } catch (_) {
                                setModalState(() => saving = false);
                                showSnack(context, 'Impossible d’enregistrer.');
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditGoalDialog(BuildContext context, String uid, int currentGoal) {
    final goalCtrl = TextEditingController(text: '$currentGoal');
    bool saving = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: Text('Modifier mon objectif', style: AppText.title(22)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nombre de séances visé par mois :',
                    style: AppText.body(12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: goalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Objectif mensuel (ex: 18)',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Annuler',
                      style: TextStyle(color: AppColors.muted)),
                ),
                TextButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final val = int.tryParse(goalCtrl.text.trim());
                          if (val == null || val <= 0) return;

                          setDialogState(() => saving = true);

                          try {
                            await _userRepo.updateMonthlyGoal(
                                uid: uid, goal: val);
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(dialogCtx);

                            if (!mounted) return;
                            showSnack(context, 'Objectif mis à jour !');
                          } catch (_) {
                            setDialogState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer',
                          style: TextStyle(color: AppColors.lime)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Connecte-toi pour consulter ta progression.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppColors.muted),
          ),
        ),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: _userRepo.getUserStream(uid),
      builder: (context, userSnapshot) {
        final appUser = userSnapshot.data;
        final monthlyGoal = appUser?.monthlyGoal ?? 18;

        return StreamBuilder<List<Workout>>(
          stream: _workoutRepo.getUserWorkoutsStream(uid),
          builder: (context, workoutSnapshot) {
            if (workoutSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Impossible de charger tes statistiques. Vérifie ta connexion.',
                    textAlign: TextAlign.center,
                    style: AppText.body(13, color: AppColors.muted),
                  ),
                ),
              );
            }

            if (workoutSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final workouts = workoutSnapshot.data ?? [];
            final now = DateTime.now();

            final monthWorkouts = workouts.where((w) {
              return w.completedAt.year == now.year &&
                  w.completedAt.month == now.month;
            }).toList();

            final startOfWeek = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: now.weekday - 1));

            final weeklyWorkouts = workouts.where((w) {
              return !w.completedAt.isBefore(startOfWeek) &&
                  w.completedAt.isBefore(startOfWeek.add(const Duration(days: 7)));
            }).toList();

            final monthlyCount = monthWorkouts.length;
            final progress = (monthlyCount / monthlyGoal).clamp(0.0, 1.0);
            final duration = weeklyWorkouts.fold<int>(
                0, (sum, w) => sum + w.durationMinutes);
            final calories = monthWorkouts.fold<int>(
                0, (sum, w) => sum + w.caloriesBurned);
            final volume = monthWorkouts.fold<int>(
                0, (sum, w) => sum + w.volumeKg);

            final dailyCounts = List<int>.filled(7, 0);
            for (final workout in weeklyWorkouts) {
              final dayIndex = workout.completedAt.weekday - 1;
              if (dayIndex >= 0 && dayIndex < 7) {
                dailyCounts[dayIndex]++;
              }
            }

            final maxCount = dailyCounts.fold<int>(
              1,
              (maxValue, count) => count > maxValue ? count : maxValue,
            );

            final labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
            final monthNames = [
              'JANVIER', 'FÉVRIER', 'MARS', 'AVRIL',
              'MAI', 'JUIN', 'JUILLET', 'AOÛT',
              'SEPTEMBRE', 'OCTOBRE', 'NOVEMBRE', 'DÉCEMBRE',
            ];

            return Scaffold(
              backgroundColor: Colors.transparent,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showAddPerformanceDialog(context, uid),
                backgroundColor: AppColors.lime,
                foregroundColor: Colors.black,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Saisir une séance',
                  style: AppText.body(12.5,
                      color: Colors.black, weight: FontWeight.w800),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                children: [
                  Text('TA PROGRESSION', style: AppText.eyebrow()),
                  const SizedBox(height: 6),
                  Text('Objectifs', style: AppText.title(36)),
                  const SizedBox(height: 6),
                  Text(
                    'Chaque effort te rapproche de ta meilleure forme.',
                    style: AppText.body(12.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 20),

                  // Carte d'objectif mensuel
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    onTap: () =>
                        _showEditGoalDialog(context, uid, monthlyGoal),
                    child: Row(
                      children: [
                        RingProgress(
                          value: progress,
                          size: 112,
                          stroke: 14,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${(progress * 100).round()}%',
                                style: AppText.title(28),
                              ),
                              Text(
                                'objectif',
                                style: AppText.body(
                                  9.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    monthNames[now.month - 1],
                                    style: AppText.eyebrow(),
                                  ),
                                  const Icon(Icons.edit_outlined,
                                      size: 16, color: AppColors.muted),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                monthlyCount == 0
                                    ? 'On commence ?'
                                    : monthlyCount >= monthlyGoal
                                        ? 'Objectif atteint !'
                                        : 'Continue tes efforts',
                                style: AppText.body(
                                  16,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$monthlyCount séance(s) sur '
                                '$monthlyGoal visée(s) ce mois-ci.',
                                style: AppText.body(
                                  11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),
                  Text(
                    'Cette semaine',
                    style: AppText.body(18, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),

                  // Graphique des séances de la semaine
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: SizedBox(
                      height: 150,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final factor = dailyCounts[i] / maxCount;

                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: FractionallySizedBox(
                                        heightFactor:
                                            factor == 0 ? 0.02 : factor,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            gradient: const LinearGradient(
                                              colors: [
                                                AppColors.lime,
                                                Color(0xFF3A4A16),
                                              ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    labels[i],
                                    style: AppText.body(
                                      9.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 26),
                  Text(
                    'Mes performances',
                    style: AppText.body(18, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),

                  _perf(
                    Icons.fitness_center_rounded,
                    AppColors.lime,
                    AppColors.limeDark,
                    '$volume kg',
                    'Volume total enregistré ce mois-ci',
                  ),
                  const SizedBox(height: 10),
                  _perf(
                    Icons.local_fire_department_outlined,
                    AppColors.purple,
                    AppColors.purpleDark,
                    '$calories kcal',
                    'Calories enregistrées ce mois-ci',
                  ),
                  const SizedBox(height: 10),
                  _perf(
                    Icons.access_time_rounded,
                    AppColors.orange,
                    AppColors.orangeDark,
                    '$duration min',
                    'Temps actif cette semaine',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _perf(
    IconData icon,
    Color color,
    Color background,
    String value,
    String label,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconBox(icon: icon, color: color, bg: background),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppText.body(15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: AppText.body(10.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
