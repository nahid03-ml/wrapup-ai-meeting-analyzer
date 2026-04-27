import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_view.dart';
import '../../meetings/application/meetings_provider.dart';
import '../../meetings/data/meeting.dart';
import '../application/action_items_provider.dart';
import '../data/action_item.dart';
import '../data/action_items_repository.dart';
import 'widgets/action_item_tile.dart';
import 'widgets/action_items_empty_state.dart';
import 'widgets/action_items_filter_chips.dart';
import 'widgets/action_items_search_bar.dart';
import 'widgets/action_items_sort_menu.dart';

class ActionItemsPage extends ConsumerStatefulWidget {
  const ActionItemsPage({super.key});

  @override
  ConsumerState<ActionItemsPage> createState() => _ActionItemsPageState();
}

class _ActionItemsPageState extends ConsumerState<ActionItemsPage> {
  final _searchController = TextEditingController();
  final _togglingIds = <String>{};

  Timer? _searchDebounce;
  bool _isSearchActive = false;
  String _searchQuery = '';
  ActionItemsFilter _selectedFilter = ActionItemsFilter.all;
  ActionItemsSortOption _selectedSort = ActionItemsSortOption.newest;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionItemsValue = ref.watch(actionItemsProvider);
    final meetingTitles = _meetingTitles(ref.watch(meetingsListProvider));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: _isSearchActive ? 'Close search' : 'Search tasks',
            onPressed: _toggleSearch,
            icon: Icon(_isSearchActive ? Icons.close : Icons.search),
          ),
          ActionItemsSortMenu(
            selected: _selectedSort,
            onChanged: (sort) => setState(() => _selectedSort = sort),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isSearchActive)
              ActionItemsSearchBar(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
            ActionItemsFilterChips(
              selected: _selectedFilter,
              onChanged: (filter) => setState(() => _selectedFilter = filter),
            ),
            Expanded(
              child: actionItemsValue.when(
                loading: _buildLoading,
                error: (error, _) => _buildError(error),
                data: (items) => _buildData(items, meetingTitles),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 5,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => const _ActionItemSkeletonTile(),
      ),
    );
  }

  Widget _buildError(Object error) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            child: ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(actionItemsProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildData(List<ActionItem> items, Map<String, String> meetingTitles) {
    final visible = _visibleItems(items);
    final hasQuery = _searchQuery.trim().isNotEmpty;

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: const [
            ActionItemsEmptyState(
              title: 'No action items yet',
              subtitle:
                  'Action items generated from meetings will appear here.',
            ),
          ],
        ),
      );
    }

    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ActionItemsEmptyState(
              title: _emptyTitle(hasQuery: hasQuery),
              subtitle: _emptySubtitle(hasQuery: hasQuery),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: visible.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = visible[index];
          return ActionItemTile(
            item: item,
            meetingTitle: meetingTitles[item.meetingId],
            isBusy: _togglingIds.contains(item.id),
            onToggle: (value) {
              unawaited(_toggleItem(item, value));
            },
          );
        },
      ),
    );
  }

  Future<void> _toggleItem(ActionItem item, bool isCompleted) async {
    setState(() => _togglingIds.add(item.id));

    try {
      await ref
          .read(actionItemsRepositoryProvider)
          .toggle(item.id, isCompleted);
      ref.invalidate(actionItemsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update task: $error')));
      ref.invalidate(actionItemsProvider);
    } finally {
      if (mounted) {
        setState(() => _togglingIds.remove(item.id));
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(actionItemsProvider);
    try {
      await ref.read(actionItemsProvider.future);
    } catch (_) {
      // The page renders provider errors inline.
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchActive = !_isSearchActive;
      if (!_isSearchActive) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _searchQuery = value.trim());
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<ActionItem> _visibleItems(List<ActionItem> items) {
    final query = _searchQuery.toLowerCase();
    final filtered = items.where((item) {
      if (!_matchesFilter(item)) return false;
      if (query.isEmpty) return true;
      return _searchHaystack(item).contains(query);
    }).toList();

    filtered.sort(_compareItems);
    return filtered;
  }

  bool _matchesFilter(ActionItem item) {
    final assignedTo = item.assignedTo?.trim();
    return switch (_selectedFilter) {
      ActionItemsFilter.all => true,
      ActionItemsFilter.pending => !item.isCompleted,
      ActionItemsFilter.completed => item.isCompleted,
      ActionItemsFilter.assigned => assignedTo != null && assignedTo.isNotEmpty,
      ActionItemsFilter.overdue => _isOverdue(item),
      ActionItemsFilter.dueSoon => _isDueSoon(item),
    };
  }

  int _compareItems(ActionItem a, ActionItem b) {
    return switch (_selectedSort) {
      ActionItemsSortOption.newest => b.createdAt.compareTo(a.createdAt),
      ActionItemsSortOption.oldest => a.createdAt.compareTo(b.createdAt),
      ActionItemsSortOption.deadlineSoonest => _compareDeadlines(a, b),
      ActionItemsSortOption.deadlineLatest => _compareDeadlines(b, a),
      ActionItemsSortOption.titleAsc => _safeTitle(a).compareTo(_safeTitle(b)),
      ActionItemsSortOption.completedLast =>
        _compareCompleted(a, b) != 0 ? _compareCompleted(a, b) : _newest(a, b),
      ActionItemsSortOption.completedFirst =>
        _compareCompleted(b, a) != 0 ? _compareCompleted(b, a) : _newest(a, b),
    };
  }

  String _emptyTitle({required bool hasQuery}) {
    if (hasQuery) return 'No matching tasks';
    return switch (_selectedFilter) {
      ActionItemsFilter.overdue => 'No overdue tasks',
      ActionItemsFilter.dueSoon => 'No upcoming deadlines',
      _ => 'No matching tasks',
    };
  }

  String _emptySubtitle({required bool hasQuery}) {
    if (hasQuery) return 'Try changing your search or filter.';
    return switch (_selectedFilter) {
      ActionItemsFilter.overdue =>
        'Everything with a deadline is still on track.',
      ActionItemsFilter.dueSoon =>
        'No incomplete tasks are due in the next 7 days.',
      _ => 'Try changing your search or filter.',
    };
  }
}

Map<String, String> _meetingTitles(AsyncValue<List<Meeting>> meetingsValue) {
  return meetingsValue.whenOrNull(
        data: (meetings) => {
          for (final meeting in meetings)
            if (meeting.id.isNotEmpty && meeting.title.trim().isNotEmpty)
              meeting.id: meeting.title.trim(),
        },
      ) ??
      const <String, String>{};
}

String _searchHaystack(ActionItem item) {
  return [
    item.title,
    item.assignedTo,
    item.meetingId,
    _metadataText(item.metadata),
  ].whereType<String>().join(' ').toLowerCase();
}

String _metadataText(Object? value) {
  if (value == null) return '';
  if (value is String || value is num || value is bool) return '$value';
  if (value is Iterable) {
    return value.map(_metadataText).where((text) => text.isNotEmpty).join(' ');
  }
  if (value is Map) {
    return value.entries
        .map((entry) => '${entry.key} ${_metadataText(entry.value)}')
        .where((text) => text.trim().isNotEmpty)
        .join(' ');
  }
  return '';
}

String _safeTitle(ActionItem item) {
  final title = item.title.trim();
  return title.isEmpty ? 'Untitled task' : title.toLowerCase();
}

int _newest(ActionItem a, ActionItem b) => b.createdAt.compareTo(a.createdAt);

int _compareCompleted(ActionItem a, ActionItem b) {
  if (a.isCompleted == b.isCompleted) return 0;
  return a.isCompleted ? 1 : -1;
}

int _compareDeadlines(ActionItem a, ActionItem b) {
  final aDeadline = a.deadline;
  final bDeadline = b.deadline;
  if (aDeadline == null && bDeadline == null) return _newest(a, b);
  if (aDeadline == null) return 1;
  if (bDeadline == null) return -1;
  final comparison = aDeadline.compareTo(bDeadline);
  return comparison == 0 ? _newest(a, b) : comparison;
}

bool _isOverdue(ActionItem item) {
  final deadline = item.deadline;
  if (deadline == null || item.isCompleted) return false;
  return deadline.toLocal().isBefore(DateTime.now());
}

bool _isDueSoon(ActionItem item) {
  final deadline = item.deadline;
  if (deadline == null || item.isCompleted) return false;
  final localDeadline = deadline.toLocal();
  final now = DateTime.now();
  return !localDeadline.isBefore(now) &&
      !localDeadline.isAfter(now.add(const Duration(days: 7)));
}

class _ActionItemSkeletonTile extends StatelessWidget {
  const _ActionItemSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: const Row(
        children: [
          _SkeletonBox(width: 24, height: 24, radius: AppSpacing.radiusSm),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: _SkeletonBox(height: 14),
                ),
                SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.48,
                  child: _SkeletonBox(height: 11),
                ),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _SkeletonBox(
                      width: 84,
                      height: 22,
                      radius: AppSpacing.radiusFull,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    _SkeletonBox(
                      width: 112,
                      height: 22,
                      radius: AppSpacing.radiusFull,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    required this.height,
    this.radius = AppSpacing.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
      ),
    );
  }
}
