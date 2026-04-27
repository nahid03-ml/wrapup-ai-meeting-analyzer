import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/error_view.dart';
import '../application/meetings_provider.dart';
import '../data/meeting.dart';
import 'widgets/meeting_card.dart';
import 'widgets/meeting_empty_state.dart';
import 'widgets/meeting_filter_chips.dart';
import 'widgets/meeting_row.dart';
import 'widgets/meeting_search_bar.dart';
import 'widgets/meeting_skeleton.dart';
import 'widgets/meeting_sort_menu.dart';
import 'widgets/meeting_view_toggle.dart';

class MeetingsListPage extends ConsumerStatefulWidget {
  const MeetingsListPage({super.key});

  @override
  ConsumerState<MeetingsListPage> createState() => _MeetingsListPageState();
}

class _MeetingsListPageState extends ConsumerState<MeetingsListPage> {
  final _searchController = TextEditingController();
  var _searchVisible = false;
  var _searchQuery = '';
  var _filter = MeetingFilter.all;
  var _sort = MeetingSortOption.newest;
  var _viewMode = MeetingViewMode.list;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchVisible = !_searchVisible;
      if (!_searchVisible) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
      });
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _refreshMeetings() async {
    ref.invalidate(meetingsListProvider);
    await ref.read(meetingsListProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final meetingsValue = ref.watch(meetingsListProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetings'),
        actions: [
          IconButton(
            tooltip: _searchVisible ? 'Hide search' : 'Search meetings',
            onPressed: _toggleSearch,
            icon: Icon(_searchVisible ? Icons.search_off : Icons.search),
          ),
          MeetingViewToggle(
            viewMode: _viewMode,
            onChanged: (mode) => setState(() => _viewMode = mode),
          ),
          MeetingSortMenu(
            selected: _sort,
            onChanged: (sort) => setState(() => _sort = sort),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _searchVisible
                  ? MeetingSearchBar(
                      key: const ValueKey('meeting-search-bar'),
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onClear: _clearSearch,
                    )
                  : const SizedBox.shrink(
                      key: ValueKey('meeting-search-empty'),
                    ),
            ),
            MeetingFilterChips(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: AsyncValueWidget<List<Meeting>>(
                value: meetingsValue,
                loading: () => _RefreshableLoading(
                  viewMode: _viewMode,
                  onRefresh: _refreshMeetings,
                ),
                error: (error, _) => _RefreshableError(
                  message: error.toString(),
                  onRefresh: _refreshMeetings,
                  onRetry: () => ref.invalidate(meetingsListProvider),
                ),
                data: (meetings) {
                  final visibleMeetings = _visibleMeetings(
                    meetings: meetings,
                    currentUserId: currentUser?.id,
                  );
                  return _MeetingsContent(
                    meetings: visibleMeetings,
                    hasAnyMeetings: meetings.isNotEmpty,
                    filter: _filter,
                    viewMode: _viewMode,
                    onRefresh: _refreshMeetings,
                    onOpenMeeting: (meeting) {
                      context.push('/dashboard/meetings/${meeting.id}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Meeting> _visibleMeetings({
    required List<Meeting> meetings,
    required String? currentUserId,
  }) {
    final query = _searchQuery.toLowerCase();
    final filtered = meetings.where((meeting) {
      final source = meeting.source?.trim().toLowerCase();

      final matchesFilter = switch (_filter) {
        MeetingFilter.all => true,
        MeetingFilter.mine =>
          currentUserId != null && meeting.ownerId == currentUserId,
        MeetingFilter.recorded => source == 'recorded' || source == 'live',
        MeetingFilter.uploaded => source == 'uploaded',
        MeetingFilter.live => source == 'live',
        // TODO(phase 8): replace with shared meeting access once mobile supports it.
        MeetingFilter.shared => false,
      };
      if (!matchesFilter) return false;

      if (query.isEmpty) return true;
      return _matchesSearch(meeting, query);
    }).toList();

    filtered.sort(_compareMeetings);
    return filtered;
  }

  int _compareMeetings(Meeting left, Meeting right) {
    return switch (_sort) {
      MeetingSortOption.newest => right.createdAt.compareTo(left.createdAt),
      MeetingSortOption.oldest => left.createdAt.compareTo(right.createdAt),
      MeetingSortOption.titleAsc => _displayTitle(
        left,
      ).toLowerCase().compareTo(_displayTitle(right).toLowerCase()),
      MeetingSortOption.titleDesc => _displayTitle(
        right,
      ).toLowerCase().compareTo(_displayTitle(left).toLowerCase()),
      MeetingSortOption.durationDesc => (right.durationMinutes ?? 0).compareTo(
        left.durationMinutes ?? 0,
      ),
      MeetingSortOption.durationAsc => (left.durationMinutes ?? 0).compareTo(
        right.durationMinutes ?? 0,
      ),
    };
  }
}

class _MeetingsContent extends StatelessWidget {
  const _MeetingsContent({
    required this.meetings,
    required this.hasAnyMeetings,
    required this.filter,
    required this.viewMode,
    required this.onRefresh,
    required this.onOpenMeeting,
  });

  final List<Meeting> meetings;
  final bool hasAnyMeetings;
  final MeetingFilter filter;
  final MeetingViewMode viewMode;
  final RefreshCallback onRefresh;
  final ValueChanged<Meeting> onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    if (filter == MeetingFilter.shared) {
      return _RefreshableEmpty(
        title: 'Shared meetings coming soon',
        subtitle: 'Shared meeting access will arrive in Phase 8.',
        onRefresh: onRefresh,
      );
    }

    if (meetings.isEmpty) {
      return _RefreshableEmpty(
        title: hasAnyMeetings ? 'No matching meetings' : 'No meetings yet',
        subtitle: hasAnyMeetings
            ? 'Try changing your search or filter.'
            : 'Upload a recording or start an instant meeting to begin.',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: viewMode == MeetingViewMode.list
          ? _MeetingsList(meetings: meetings, onOpenMeeting: onOpenMeeting)
          : _MeetingsGrid(meetings: meetings, onOpenMeeting: onOpenMeeting),
    );
  }
}

class _MeetingsList extends StatelessWidget {
  const _MeetingsList({required this.meetings, required this.onOpenMeeting});

  final List<Meeting> meetings;
  final ValueChanged<Meeting> onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: meetings.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        return MeetingRow(
          meeting: meeting,
          onTap: () => onOpenMeeting(meeting),
        );
      },
    );
  }
}

class _MeetingsGrid extends StatelessWidget {
  const _MeetingsGrid({required this.meetings, required this.onOpenMeeting});

  final List<Meeting> meetings;
  final ValueChanged<Meeting> onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 700 ? 2 : 1;
        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: 272,
          ),
          itemCount: meetings.length,
          itemBuilder: (context, index) {
            final meeting = meetings[index];
            return MeetingCard(
              meeting: meeting,
              onTap: () => onOpenMeeting(meeting),
            );
          },
        );
      },
    );
  }
}

class _RefreshableLoading extends StatelessWidget {
  const _RefreshableLoading({required this.viewMode, required this.onRefresh});

  final MeetingViewMode viewMode;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          MeetingSkeleton(
            compact: viewMode == MeetingViewMode.grid,
            count: viewMode == MeetingViewMode.grid ? 4 : 5,
          ),
        ],
      ),
    );
  }
}

class _RefreshableEmpty extends StatelessWidget {
  const _RefreshableEmpty({
    required this.title,
    required this.subtitle,
    required this.onRefresh,
  });

  final String title;
  final String subtitle;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: MeetingEmptyState(title: title, subtitle: subtitle),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshableError extends StatelessWidget {
  const _RefreshableError({
    required this.message,
    required this.onRefresh,
    required this.onRetry,
  });

  final String message;
  final RefreshCallback onRefresh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xxl,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Card(
            child: ErrorView(message: message, onRetry: onRetry),
          ),
        ],
      ),
    );
  }
}

bool _matchesSearch(Meeting meeting, String query) {
  final latestSession = meeting.latestSession;
  final fields = <String>[
    meeting.title,
    if (meeting.source != null) meeting.source!,
    if (latestSession?.transcript != null) latestSession!.transcript!,
    ..._summarySearchFields(latestSession?.summary),
  ];

  return fields.any((field) => field.toLowerCase().contains(query));
}

Iterable<String> _summarySearchFields(Map<String, dynamic>? summary) sync* {
  if (summary == null) return;
  for (final key in const ['overview', 'summary', 'executive_summary']) {
    final value = summary[key];
    if (value is String && value.trim().isNotEmpty) {
      yield value.trim();
    }
  }
}

String _displayTitle(Meeting meeting) {
  final trimmed = meeting.title.trim();
  return trimmed.isEmpty ? 'Untitled Meeting' : trimmed;
}
