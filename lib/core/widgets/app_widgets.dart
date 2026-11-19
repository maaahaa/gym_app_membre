import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Carte arrondie avec bordure fine (utilisée partout).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;
  final double radius;

  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      this.gradient,
      this.borderColor,
      this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.surface : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// En-tête de page : petit titre vert + grand titre + cloche optionnelle.
class PageHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final bool showBell;
  final bool hasUnread;
  final int unreadCount;
  final VoidCallback? onBell;

  const PageHeader(
      {super.key,
      required this.eyebrow,
      required this.title,
      this.subtitle,
      this.showBell = false,
      this.hasUnread = false,
      this.unreadCount = 0,
      this.onBell});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow, style: AppText.eyebrow()),
              const SizedBox(height: 6),
              Text(title, style: AppText.title(34)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!,
                    style: AppText.body(12.5, color: AppColors.muted)),
              ],
            ],
          ),
        ),
        if (showBell)
          InkWell(
            onTap: onBell,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border)),
              child: Stack(alignment: Alignment.center, children: [
                const Icon(Icons.notifications_none_rounded, size: 22),
                if (hasUnread)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: EdgeInsets.all(unreadCount > 9 ? 2 : 4),
                      constraints: const BoxConstraints(
                        minWidth: 9,
                        minHeight: 9,
                      ),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.red,
                      ),
                      child: unreadCount > 0
                          ? Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// Titre de section + lien à droite ("Voir tout").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppText.body(18, weight: FontWeight.w600)),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: AppText.body(12,
                    color: AppColors.muted, weight: FontWeight.w600)),
          ),
      ],
    );
  }
}

class IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final double size;
  const IconBox(
      {super.key,
      required this.icon,
      this.color = AppColors.lime,
      this.bg = AppColors.limeDark,
      this.size = 40});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

/// Tuile de statistique (icône colorée + valeur + libellé).
class StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;
  final String? caption;
  final Color captionColor;
  final VoidCallback? onTap;

  const StatTile(
      {super.key,
      required this.icon,
      required this.iconColor,
      required this.iconBg,
      required this.value,
      required this.label,
      this.caption,
      this.captionColor = AppColors.lime,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBox(icon: icon, color: iconColor, bg: iconBg),
          const SizedBox(height: 14),
          Text(value, style: AppText.title(28)),
          const SizedBox(height: 4),
          Text(label, style: AppText.body(12, color: AppColors.muted)),
          if (caption != null) ...[
            const SizedBox(height: 10),
            Text(caption!,
                style: AppText.body(11,
                    color: captionColor, weight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

/// Pastille (ex: "ABONNEMENT ACTIF", "EN DIRECT").
class PillBadge extends StatelessWidget {
  final String label;
  final bool dot;
  final Color color;
  const PillBadge(this.label,
      {super.key, this.dot = true, this.color = AppColors.lime});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot) ...[
            Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: AppText.body(10, color: color, weight: FontWeight.w800)),
        ]),
      );
}

/// Bouton principal vert citron.
class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final bool small;
  const PrimaryButton(this.label,
      {super.key,
      this.icon,
      this.onPressed,
      this.expand = true,
      this.small = false});

  @override
  Widget build(BuildContext context) {
    final btn = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: EdgeInsets.symmetric(
            horizontal: small ? 16 : 24, vertical: small ? 10 : 18),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(small ? 12 : 18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
        Text(label,
            style: AppText.body(small ? 11 : 14,
                color: Colors.black, weight: FontWeight.w800)),
      ]),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Avatar rond avec initiales (dégradé violet par défaut).
class AvatarCircle extends StatelessWidget {
  final String initials;
  final double size;
  final List<Color> colors;
  const AvatarCircle(this.initials,
      {super.key,
      this.size = 56,
      this.colors = const [Color(0xFFC4B5FD), Color(0xFF8B5CF6)]});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)),
        child: Text(initials,
            style: AppText.body(size * 0.3,
                color: Colors.black87, weight: FontWeight.w800)),
      );
}

/// Pastille de date (MAR / 18).
class DateBadge extends StatelessWidget {
  final String month;
  final int day;
  final double size;
  const DateBadge(
      {super.key, required this.month, required this.day, this.size = 64});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.lime, borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(month,
              style: AppText.body(10,
                  color: Colors.black, weight: FontWeight.w800)),
          Text('$day', style: AppText.title(size * 0.4, color: Colors.black)),
        ]),
      );
}

/// Ligne de menu avec icône et chevron (écran Profil).
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const MenuRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            IconBox(icon: icon),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: AppText.body(13, weight: FontWeight.w700))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      );
}

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

/// Barre de navigation du bas (onglet actif en pastille verte).
class AppBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  const AppBottomNav(
      {super.key,
      required this.items,
      required this.index,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final active = i == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 58,
                      height: 38,
                      decoration: BoxDecoration(
                          color:
                              active ? AppColors.limeDark : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: active
                              ? Border.all(
                                  color: AppColors.lime.withValues(alpha: 0.25))
                              : null),
                      child: Icon(items[i].icon,
                          size: 22,
                          color: active ? AppColors.lime : AppColors.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(items[i].label,
                        style: AppText.body(10,
                            color: active ? AppColors.lime : AppColors.muted,
                            weight:
                                active ? FontWeight.w800 : FontWeight.w500)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
