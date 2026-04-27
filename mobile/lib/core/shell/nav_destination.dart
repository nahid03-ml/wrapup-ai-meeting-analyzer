import 'package:flutter/material.dart';

enum NavDestination {
  home(
    label: 'Home',
    route: '/dashboard/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  meetings(
    label: 'Meetings',
    route: '/dashboard/meetings',
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
  ),
  newMeeting(
    label: 'New',
    route: '/dashboard/new',
    icon: Icons.add_circle_outline,
    selectedIcon: Icons.add_circle,
  ),
  tasks(
    label: 'Tasks',
    route: '/dashboard/action-items',
    icon: Icons.task_alt_outlined,
    selectedIcon: Icons.task_alt,
  ),
  profile(
    label: 'Profile',
    route: '/dashboard/profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );

  const NavDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;
}
