import 'package:flutter/material.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/role_shell.dart';
import 'member_home.dart';
import 'member_profile.dart';
import 'member_progress.dart';
import 'member_sessions.dart';

class MemberShell extends StatelessWidget {
  const MemberShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleShell(
      items: [
        NavItem(Icons.home_outlined, 'Accueil'),
        NavItem(Icons.calendar_today_outlined, 'Séances'),
        NavItem(Icons.bar_chart_rounded, 'Progrès'),
        NavItem(Icons.person_outline_rounded, 'Profil'),
      ],
      pages: [
        MemberHome(),
        MemberSessions(),
        MemberProgress(),
        MemberProfile(),
      ],
    );
  }
}
