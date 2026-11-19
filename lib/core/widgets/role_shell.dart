import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_widgets.dart';

/// Coquille commune : pages + barre de navigation du bas.
class RoleShell extends StatefulWidget {
  final List<NavItem> items;
  final List<Widget> pages;
  const RoleShell({super.key, required this.items, required this.pages});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: widget.pages),
      ),
      bottomNavigationBar: AppBottomNav(
        items: widget.items,
        index: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
