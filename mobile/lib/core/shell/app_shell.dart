import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'nav_destination.dart' as shell;

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.16),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: [
              for (final destination in shell.NavDestination.values)
                NavigationDestination(
                  icon: Icon(destination.icon, color: AppColors.textSecondary),
                  selectedIcon: Icon(
                    destination.selectedIcon,
                    color: AppColors.primary,
                  ),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
