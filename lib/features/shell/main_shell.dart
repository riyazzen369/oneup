import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/fx.dart';
import '../../core/services/haptics.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  int _last = -1;

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    if (_last != shell.currentIndex) {
      if (_last != -1 && !reducedMotion(context)) _fade.forward(from: 0.4);
      _last = shell.currentIndex;
    }
    // 6 tabs: show every label at normal text sizes; at large text show only the selected label.
    final large = MediaQuery.textScalerOf(context).scale(12) > 14;
    return Scaffold(
      body: FadeTransition(opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut), child: shell),
      bottomNavigationBar: NavigationBarTheme(
        data: const NavigationBarThemeData(
          labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ),
        child: NavigationBar(
          labelBehavior: large ? NavigationDestinationLabelBehavior.onlyShowSelected : NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) {
            Haptics.light();
            shell.goBranch(i, initialLocation: i == shell.currentIndex);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined), selectedIcon: Icon(Icons.sports_esports_rounded), label: 'Games'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book_rounded), label: 'Learn'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront_rounded), label: 'Market'),
            NavigationDestination(
                icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent_rounded), label: 'Consult'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
