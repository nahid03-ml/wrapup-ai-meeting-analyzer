import 'package:flutter/material.dart';

enum MeetingViewMode { list, grid }

class MeetingViewToggle extends StatelessWidget {
  const MeetingViewToggle({
    required this.viewMode,
    required this.onChanged,
    super.key,
  });

  final MeetingViewMode viewMode;
  final ValueChanged<MeetingViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final nextMode = viewMode == MeetingViewMode.list
        ? MeetingViewMode.grid
        : MeetingViewMode.list;
    final tooltip = nextMode == MeetingViewMode.grid
        ? 'Grid view'
        : 'List view';
    final icon = nextMode == MeetingViewMode.grid
        ? Icons.grid_view_outlined
        : Icons.view_list_outlined;

    return IconButton(
      tooltip: tooltip,
      onPressed: () => onChanged(nextMode),
      icon: Icon(icon),
    );
  }
}
