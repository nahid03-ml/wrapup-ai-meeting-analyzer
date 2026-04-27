import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum ActionItemsSortOption {
  newest,
  oldest,
  deadlineSoonest,
  deadlineLatest,
  titleAsc,
  completedLast,
  completedFirst,
}

extension ActionItemsSortOptionLabel on ActionItemsSortOption {
  String get label {
    return switch (this) {
      ActionItemsSortOption.newest => 'Newest first',
      ActionItemsSortOption.oldest => 'Oldest first',
      ActionItemsSortOption.deadlineSoonest => 'Deadline soonest',
      ActionItemsSortOption.deadlineLatest => 'Deadline latest',
      ActionItemsSortOption.titleAsc => 'Title A-Z',
      ActionItemsSortOption.completedLast => 'Completed last',
      ActionItemsSortOption.completedFirst => 'Completed first',
    };
  }
}

class ActionItemsSortMenu extends StatelessWidget {
  const ActionItemsSortMenu({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final ActionItemsSortOption selected;
  final ValueChanged<ActionItemsSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ActionItemsSortOption>(
      tooltip: 'Sort tasks',
      initialValue: selected,
      icon: const Icon(Icons.sort),
      color: AppColors.surfaceElevated,
      onSelected: onChanged,
      itemBuilder: (context) {
        return ActionItemsSortOption.values.map((option) {
          return CheckedPopupMenuItem<ActionItemsSortOption>(
            value: option,
            checked: option == selected,
            child: Text(option.label),
          );
        }).toList();
      },
    );
  }
}
