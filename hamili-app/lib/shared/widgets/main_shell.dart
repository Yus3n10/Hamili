import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/budgets/presentation/budget_alert_overlay.dart';
import '../../features/goals/presentation/goal_alert_overlay.dart';

/// Bottom-nav shell wrapping the core screens. Dashboard, transactions,
/// analytics, chat are one tap away; budgets/goals/recurring/profile live
/// under "More". Switching tabs glides the new branch in (slide + fade),
/// with the direction following whether you moved forward or back.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  int _lastIndex = 0;
  bool _forward = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.navigationShell.currentIndex;
    if (current != _lastIndex) {
      _forward = current > _lastIndex;
      _lastIndex = current;
      // Replay the glide-in after this frame (can't drive an animation mid-build).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward(from: 0);
      });
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final width = MediaQuery.of(context).size.width;
              final dx = (1 - _controller.value) * (_forward ? 0.05 : -0.05) * width;
              return Opacity(
                opacity: 0.35 + 0.65 * _controller.value,
                child: Transform.translate(offset: Offset(dx, 0), child: child),
              );
            },
            child: widget.navigationShell,
          ),
          const BudgetAlertOverlay(),
          const GoalAlertOverlay(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        // Always reset the branch to its root on tab tap, so a pushed sheet
        // (e.g. add-transaction) doesn't linger when you come back to the tab.
        onDestinationSelected: (index) => widget.navigationShell.goBranch(index, initialLocation: true),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Transactions'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Hami'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
