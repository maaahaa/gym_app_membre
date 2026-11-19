import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/models.dart';
import '../../repositories/coach_repository.dart';
import '../../repositories/program_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import 'coaches_screen.dart';
import 'profile_sub_screens.dart';

/// Écran du programme personnalisé d'entraînement.

class ProgramScreen extends StatefulWidget {
  const ProgramScreen({super.key});

  @override
  State<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends State<ProgramScreen> {
  final Set<String> _done = {};
  final ProgramRepository _programRepo = ProgramRepository();
  final UserRepository _userRepo = UserRepository();
  final CoachRepository _coachRepo = CoachRepository();
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return const SubScaffold(
        title: 'Programme personnalisé',
        child: Center(
          child: Text('Connectez-vous pour voir votre programme.'),
        ),
      );
    }

    return SubScaffold(
      title: 'Mon programme',
      child: StreamBuilder<AppUser?>(
        stream: _userRepo.getUserStream(uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final appUser = userSnapshot.data;
          final hasPrivateCoach = appUser?.hasPrivateCoach == true &&
              appUser?.privateCoachId != null &&
              appUser!.privateCoachId!.isNotEmpty;
          final privateCoachId = appUser?.privateCoachId ?? '';

          // ----------------------------------------------------
          // ----------------------------------------------------
          if (!hasPrivateCoach) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.fitness_center_outlined,
                      size: 34,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Aucun coach privé assigné',
                  textAlign: TextAlign.center,
                  style: AppText.title(22),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les programmes personnalisés sont réservés aux adhérents disposant d’un coach privé attitré.',
                  textAlign: TextAlign.center,
                  style: AppText.body(13, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.lime, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Accès aux séances',
                            style: AppText.body(14, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Text(
                        'Consultez la liste des coachs pour choisir un coach privé et bénéficier d’un programme personnalisé.',
                        style: AppText.body(12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  'Voir les coachs de la salle',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CoachesScreen(),
                    ),
                  ),
                ),
              ],
            );
          }



          return StreamBuilder<Coach?>(
            stream: _coachRepo.getCoachStream(privateCoachId),
            builder: (context, coachSnapshot) {
              final coach = coachSnapshot.data;

              return StreamBuilder<Program?>(
                stream: _programRepo.getPrivateCoachProgramStream(
                  memberId: uid,
                  coachId: privateCoachId,
                ),
                builder: (context, programSnapshot) {
                  if (programSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final program = programSnapshot.data;

                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Carte du coach privé
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            coach?.photoUrl != null &&
                                    coach!.photoUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      coach.photoUrl!,
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => AvatarCircle(
                                          coach.initials,
                                          size: 52),
                                    ),
                                  )
                                : AvatarCircle(
                                    coach?.initials ?? 'CP',
                                    size: 52,
                                  ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const PillBadge('TON COACH PRIVÉ',
                                      dot: false, color: AppColors.lime),
                                  const SizedBox(height: 4),
                                  Text(
                                    coach?.name ??
                                        program?.coachName ??
                                        'Coach Privé',
                                    style: AppText.body(16,
                                        weight: FontWeight.w700),
                                  ),
                                  if (coach != null &&
                                      coach.specialties.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      coach.specialties.join(' · '),
                                      style: AppText.body(11,
                                          color: AppColors.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // État si le coach privé n'a pas encore créé de programme
                      if (program == null)
                        AppCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.assignment_outlined,
                                size: 44,
                                color: AppColors.muted,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Programme en attente',
                                style: AppText.title(18),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                coach != null
                                    ? 'Ton coach privé ${coach.name} ne t\u2019a pas encore assigné de programme personnalisé.'
                                    : 'Ton coach privé prépare ton programme personnalisé. Il apparaîtra ici dès qu\u2019il sera validé.',
                                textAlign: TextAlign.center,
                                style:
                                    AppText.body(12.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // Titre du programme et détails
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PROGRAMME ASSIGNÉ',
                                    style: AppText.eyebrow(),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    program.title,
                                    style: AppText.title(24),
                                  ),
                                ],
                              ),
                            ),
                            if (program.duration != null &&
                                program.duration!.isNotEmpty)
                              PillBadge(
                                program.duration!,
                                dot: false,
                                color: AppColors.purple,
                              ),
                          ],
                        ),

                        // Jours d'entraînement
                        if (program.trainingDays.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Jours d\u2019entraînement',
                            style: AppText.body(12,
                                weight: FontWeight.w700, color: AppColors.lime),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: program.trainingDays.map((day) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  day,
                                  style: AppText.body(11,
                                      weight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Liste des exercices
                        if (program.exercises.isEmpty)
                          AppCard(
                            child: Text(
                              'Ton coach n\u2019a pas encore renseigné d\u2019exercices pour ce programme.',
                              style:
                                  AppText.body(13, color: AppColors.muted),
                            ),
                          )
                        else ...[
                          Text(
                            '${program.exercises.length} exercices prévus',
                            style: AppText.body(16, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ...program.exercises.map((ex) {
                            final done = _done.contains(ex.id);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AppCard(
                                padding: const EdgeInsets.all(14),
                                onTap: () => setState(() => done
                                    ? _done.remove(ex.id)
                                    : _done.add(ex.id)),
                                child: Row(
                                  children: [
                                    Icon(
                                      done
                                          ? Icons.check_circle_rounded
                                          : Icons.circle_outlined,
                                      color: done
                                          ? AppColors.lime
                                          : AppColors.muted,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ex.name,
                                            style: AppText.body(14,
                                                    weight: FontWeight.w700)
                                                .copyWith(
                                              decoration: done
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${ex.sets} séries · ${ex.reps} répétitions'
                                            '${ex.restSeconds > 0 ? ' · repos ${ex.restSeconds} s' : ''}',
                                            style: AppText.body(11,
                                                color: AppColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],

                        // Consignes & Notes
                        if (program.notes.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AppCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.lightbulb_outline_rounded,
                                      size: 18,
                                      color: AppColors.lime,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('CONSIGNES DU COACH',
                                        style: AppText.eyebrow()),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  program.notes,
                                  style: AppText.body(12,
                                      color: AppColors.text),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
