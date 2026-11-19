import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../models/models.dart';
import '../../repositories/subscription_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'profile_sub_screens.dart';
import 'program_screen.dart';
import 'subscriptions_screen.dart';

class MemberProfile extends StatelessWidget {
  const MemberProfile({super.key});

  void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final uid = user?.uid ?? '';

    final userRepo = UserRepository();
    final subRepo = SubscriptionRepository();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // En-tête profil utilisateur
        StreamBuilder<AppUser?>(
          stream: userRepo.getUserStream(uid),
          builder: (context, snapshot) {
            final appUser = snapshot.data;
            final name = appUser?.name.isNotEmpty == true
                ? appUser!.name
                : 'Utilisateur';
            final initials = appUser?.initials ?? 'U';

            return Row(
              children: [
                AvatarCircle(initials, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ESPACE ADHÉRENT', style: AppText.eyebrow()),
                      const SizedBox(height: 4),
                      Text(name, style: AppText.title(26)),
                      const SizedBox(height: 4),
                      Text(
                        appUser?.email ?? '',
                        style: AppText.body(11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 22),

        // Carte abonnement courant
        StreamBuilder<Subscription?>(
          stream: subRepo.getUserSubscriptionStream(uid),
          builder: (context, snapshot) {
            final sub = snapshot.data;
            final isActive = sub != null && sub.isActive;
            final startLabel =
                sub?.startAt != null ? _formatDate(sub!.startAt!) : '--';
            final endLabel =
                sub?.endAt != null ? _formatDate(sub!.endAt!) : '--';
            final statusColor = sub?.isActive == true
                ? AppColors.lime
                : sub?.isPending == true
                    ? AppColors.orange
                    : AppColors.muted;

            return AppCard(
              padding: const EdgeInsets.all(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF2B3512), Color(0xFF171913)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderColor: AppColors.lime.withValues(alpha: 0.3),
              onTap: () => _open(context, const SubscriptionsScreen()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ABONNEMENT', style: AppText.eyebrow()),
                      PillBadge(
                        sub?.statusLabel ?? 'INACTIF',
                        color: statusColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(sub?.planName ?? 'AUCUN ABONNEMENT',
                      style: AppText.title(26)),
                  const SizedBox(height: 4),
                  Text(
                    isActive
                        ? 'Accès illimité · Toutes activités'
                        : sub?.isPending == true
                            ? 'Ta demande sera activée après validation par l’administration.'
                            : sub?.isRejected == true
                                ? 'Ta demande a été refusée. Tu peux choisir une autre formule.'
                                : 'Souscris à un abonnement pour commencer',
                    style: AppText.body(11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _date('Début', startLabel),
                      const SizedBox(width: 40),
                      _date('Expiration', endLabel),
                    ],
                  ),
                  if (isActive && sub.daysLeft != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      sub.daysLeft == 0
                          ? 'Expire aujourd\u2019hui'
                          : '${sub.daysLeft} jour${sub.daysLeft! > 1 ? 's' : ''} restant${sub.daysLeft! > 1 ? 's' : ''}',
                      style: AppText.body(
                        11.5,
                        color: sub.daysLeft! <= 5
                            ? AppColors.orange
                            : AppColors.lime,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 26),

        Text('Mon compte', style: AppText.body(18, weight: FontWeight.w600)),
        const SizedBox(height: 14),

        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              MenuRow(
                icon: Icons.fitness_center_rounded,
                label: 'Mon programme personnalisé',
                onTap: () => _open(context, const ProgramScreen()),
              ),
              const Divider(color: AppColors.border, height: 1),
              MenuRow(
                icon: Icons.person_outline_rounded,
                label: 'Informations personnelles',
                onTap: () => _open(context, const PersonalInfoScreen()),
              ),
              const Divider(color: AppColors.border, height: 1),
              MenuRow(
                icon: Icons.calendar_today_outlined,
                label: 'Mes réservations',
                onTap: () => _open(context, const MyReservationsScreen()),
              ),
              const Divider(color: AppColors.border, height: 1),
              MenuRow(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                onTap: () => _open(context, const NotificationsScreen()),
              ),
              const Divider(color: AppColors.border, height: 1),
              MenuRow(
                icon: Icons.bar_chart_rounded,
                label: "Historique d'activités",
                onTap: () => _open(context, const HistoryScreen()),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        OutlinedButton.icon(
          onPressed: () async {
            await authService.signOut();
            if (!context.mounted) return;
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (r) => false,
            );
          },
          icon:
              const Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
          label: Text(
            'Se déconnecter',
            style:
                AppText.body(13, color: AppColors.red, weight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: AppColors.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  Widget _date(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.body(10, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(value, style: AppText.body(12, weight: FontWeight.w800)),
        ],
      );

  static String _formatDate(DateTime d) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
