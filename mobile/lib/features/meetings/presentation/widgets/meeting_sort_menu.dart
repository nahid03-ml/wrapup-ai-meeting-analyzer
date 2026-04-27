import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

enum MeetingSortOption {
  newest,
  oldest,
  titleAsc,
  titleDesc,
  durationDesc,
  durationAsc,
}

extension MeetingSortOptionLabel on MeetingSortOption {
  String get label {
    return switch (this) {
      MeetingSortOption.newest => 'Newest first',
      MeetingSortOption.oldest => 'Oldest first',
      MeetingSortOption.titleAsc => 'Title A-Z',
      MeetingSortOption.titleDesc => 'Title Z-A',
      MeetingSortOption.durationDesc => 'Duration desc',
      MeetingSortOption.durationAsc => 'Duration asc',
    };
  }
}

class MeetingSortMenu extends StatelessWidget {
  const MeetingSortMenu({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final MeetingSortOption selected;
  final ValueChanged<MeetingSortOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MeetingSortOption>(
      tooltip: 'Sort meetings',
      initialValue: selected,
      icon: const Icon(Icons.sort),
      color: AppColors.surfaceElevated,
      onSelected: onChanged,
      itemBuilder: (context) {
        return MeetingSortOption.values.map((option) {
          return CheckedPopupMenuItem<MeetingSortOption>(
            value: option,
            checked: option == selected,
            child: Text(option.label),
          );
        }).toList();
      },
    );
  }
}
