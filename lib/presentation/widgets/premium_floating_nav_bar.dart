import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/haptic_provider.dart';
import 'glass_floating_nav_bar.dart';

// ─── Data model ──────────────────────────────────────────────────────────────

class NavBarItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const NavBarItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

// ─── Premium floating nav bar backed by authentic Liquid Water Bubble Physics ──

class PremiumFloatingNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavBarItem> items;
  final double bottomSafeArea;
  final ValueNotifier<double>? pageNotifier;

  const PremiumFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.pageNotifier,
    this.bottomSafeArea = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hapticLevel = ref.watch(hapticProvider);

    final glassItems = items.map((it) {
      return GlassNavItemData(
        icon: it.inactiveIcon,
        selectedIcon: it.activeIcon,
        label: it.label,
      );
    }).toList();

    return GlassFloatingNavBar(
      currentIndex: currentIndex,
      onTabSelected: onTap,
      isDark: isDark,
      items: glassItems,
      pageNotifier: pageNotifier,
      bottomSafeArea: bottomSafeArea,
      hapticLevel: hapticLevel,
    );
  }
}
