import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/models.dart';
import '../../repositories/subscription_repository.dart';
import '../../services/auth_service.dart';
import 'profile_sub_screens.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final AuthService _authService = AuthService();
  final SubscriptionRepository _subRepo = SubscriptionRepository();
  bool _subscribing = false;
  String _selectedCategory = 'Tous';

  static const _categories = [
    'Tous',
    'Abonnements Globaux',
    'Par Séance / Workout',
  ];

  Future<void> _onSubscribe(
    BuildContext context,
    String uid,
    SubscriptionPlan plan,
    Subscription? currentSub,
  ) async {
    // Contrainte : Refus si le membre possède déjà un abonnement actif non expiré
    if (currentSub != null && currentSub.isActive) {
      final endLabel =
          currentSub.endAt != null ? formatDate(currentSub.endAt!) : 'bientôt';

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Souscription refusée',
            style: AppText.title(22, color: AppColors.red),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tu possèdes déjà un abonnement actif :',
                style: AppText.body(13, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              Text(
                currentSub.planName,
                style: AppText.body(15,
                    weight: FontWeight.w800, color: AppColors.lime),
              ),
              const SizedBox(height: 4),
              Text(
                'Valable jusqu’au $endLabel.',
                style: AppText.body(12,
                    color: AppColors.text, weight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu dois attendre la fin de ton abonnement actuel avant de souscrire à une nouvelle formule.',
                style: AppText.body(12, color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Compris',
                style: TextStyle(color: AppColors.lime),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (currentSub?.isPending == true) {
      showSnack(context, 'Ta demande est déjà en attente de validation.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Confirmer la souscription ?', style: AppText.title(22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${plan.name} · ${plan.price} DT',
              style: AppText.body(15, weight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Durée / Format : ${plan.durationDisplay}',
              style: AppText.body(12,
                  color: AppColors.lime, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Ta demande sera transmise à l’administrateur. '
              'L’abonnement ne sera actif qu’après validation.',
              style: AppText.body(12, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Annuler', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer',
                style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _subscribing = true);

    try {
      await _subRepo.requestSubscription(uid: uid, plan: plan);
      if (!context.mounted) return;
      showSnack(context, 'Demande envoyée. En attente de validation.');
    } on StateError catch (error) {
      if (!context.mounted) return;
      final message = switch (error.message) {
        'SUBSCRIPTION_ALREADY_PENDING' =>
          'Une demande est déjà en attente de validation.',
        'SUBSCRIPTION_ALREADY_ACTIVE' =>
          'Tu possèdes déjà un abonnement actif.',
        'PLAN_UNAVAILABLE' => 'Cette formule n’est plus disponible.',
        'ACCOUNT_NOT_MEMBER' => 'Ce compte n’est pas un compte adhérent.',
        'MEMBER_PROFILE_NOT_FOUND' =>
          'Ton profil adhérent est introuvable. Reconnecte-toi.',
        _ => 'Impossible d’envoyer la demande.',
      };
      showSnack(context, message);
    } catch (_) {
      if (!context.mounted) return;
      showSnack(context, 'Impossible d’envoyer la demande.');
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final uid = user?.uid ?? '';

    if (uid.isEmpty) {
      return const SubScaffold(
        title: 'Mon abonnement',
        child: Center(
          child: Text('Veuillez vous connecter pour voir vos abonnements.'),
        ),
      );
    }

    return SubScaffold(
      title: 'Mon abonnement',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Carte abonnement actuel du membre
          StreamBuilder<Subscription?>(
            stream: _subRepo.getUserSubscriptionStream(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final sub = snapshot.data;
              final isActive = sub != null && sub.isActive;
              final statusColor = sub?.isActive == true
                  ? AppColors.lime
                  : sub?.isPending == true
                      ? AppColors.orange
                      : AppColors.muted;

              // Date de début : uniquement depuis Firestore, jamais la date actuelle
              final startLabel =
                  sub?.startAt != null ? formatDate(sub!.startAt!) : '--';
              // Date d'expiration : uniquement depuis Firestore
              final endLabel = sub?.endAt != null
                  ? formatDate(sub!.endAt!)
                  : sub?.isPerSession == true
                      ? 'Sans expiration par date'
                      : '--';

              // Jours restants calculés sans décalage de fuseau horaire
              final daysLeft = sub?.daysLeft;

              return AppCard(
                padding: const EdgeInsets.all(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B3512), Color(0xFF171913)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PillBadge(
                      sub?.statusLabel ?? 'INACTIF',
                      color: statusColor,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      sub?.planName ?? 'AUCUN ABONNEMENT',
                      style: AppText.title(30),
                    ),
                    if (isActive && sub.priceTnd > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Tarif : ${sub.priceTnd} DT',
                        style: AppText.body(12,
                            color: AppColors.lime, weight: FontWeight.w700),
                      ),
                    ],
                    if (isActive && sub.sessionsLeft != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Séances restantes : ${sub.sessionsLeft}',
                        style: AppText.body(12,
                            color: AppColors.orange, weight: FontWeight.w700),
                      ),
                    ],
                    if (sub != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Type : ${sub.planTypeLabel}',
                        style: AppText.body(12.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Durée : ${sub.durationLabel}',
                        style: AppText.body(12.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Date de début : $startLabel',
                        style: AppText.body(12.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Date d’expiration : $endLabel',
                        style: AppText.body(12.5, weight: FontWeight.w700),
                      ),
                    ],
                    // Jours restants
                    if (daysLeft != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        daysLeft == 0
                            ? 'Expire aujourd\u2019hui'
                            : '$daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}',
                        style: AppText.body(
                          12,
                          color:
                              daysLeft <= 7 ? AppColors.orange : AppColors.lime,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (sub == null || (!isActive && !sub.isPending)) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Aucun abonnement actif. Découvre nos formules ci-dessous.',
                        style: AppText.body(11.5, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 26),
          Text(
            'Formules & Tarifs',
            style: AppText.body(18, weight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Filtres par type de forfait
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final active = cat == _selectedCategory;

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.lime : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active ? AppColors.lime : AppColors.border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: AppText.body(
                        11,
                        color: active ? Colors.black : AppColors.muted,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Liste des forfaits disponibles
          StreamBuilder<Subscription?>(
            stream: _subRepo.getUserSubscriptionStream(uid),
            builder: (context, currentSubSnapshot) {
              final currentSub = currentSubSnapshot.data;
              final activePlanId =
                  currentSub?.isActive == true ? currentSub!.planId : '';
              final requestPending = currentSub?.isPending == true;

              return StreamBuilder<List<SubscriptionPlan>>(
                stream: _subRepo.getSubscriptionPlansStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allPlans = snapshot.data ?? [];

                  final filteredPlans = allPlans.where((p) {
                    if (!p.isActive) return false;
                    if (_selectedCategory == 'Abonnements Globaux') {
                      return !p.isPerSession;
                    } else if (_selectedCategory == 'Par Séance / Workout') {
                      return p.isPerSession;
                    }
                    return true;
                  }).toList();

                  if (filteredPlans.isEmpty) {
                    return AppCard(
                      child: Text(
                        'Aucune formule disponible dans cette catégorie.',
                        style: AppText.body(13, color: AppColors.muted),
                      ),
                    );
                  }

                  return Column(
                    children: filteredPlans.map((p) {
                      final isCurrentPlan = p.id == activePlanId ||
                          (currentSub?.isActive == true &&
                              currentSub!.planName.toLowerCase() ==
                                  p.name.toLowerCase());

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          borderColor: isCurrentPlan
                              ? AppColors.lime.withValues(alpha: 0.5)
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: AppText.body(15,
                                              weight: FontWeight.w800),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.isPerSession
                                              ? 'Format : ${p.durationDisplay}'
                                              : 'Accès illimité · ${p.durationDisplay}',
                                          style: AppText.body(11,
                                              color: AppColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${p.price} DT',
                                        style: AppText.title(22,
                                            color: AppColors.lime),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (p.benefits.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ...p.benefits.map(
                                  (b) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_rounded,
                                            size: 15, color: AppColors.lime),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(b,
                                              style: AppText.body(11.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              isCurrentPlan
                                  ? const PillBadge('FORFAIT ACTUEL', dot: true)
                                  : requestPending
                                      ? const PillBadge(
                                          'DEMANDE EN ATTENTE',
                                          color: AppColors.orange,
                                          dot: false,
                                        )
                                      : PrimaryButton(
                                          _subscribing
                                              ? 'Traitement...'
                                              : 'Souscrire',
                                          small: true,
                                          expand: false,
                                          onPressed: _subscribing
                                              ? null
                                              : () => _onSubscribe(
                                                    context,
                                                    uid,
                                                    p,
                                                    currentSub,
                                                  ),
                                        ),
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
        ],
      ),
    );
  }
}
