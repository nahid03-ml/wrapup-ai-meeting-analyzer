import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/async_value_widget.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../application/meeting_detail_provider.dart';
import '../../../data/note.dart';

class NotesTab extends ConsumerWidget {
  const NotesTab({required this.meetingId, super.key});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesValue = ref.watch(notesProvider(meetingId));

    return AsyncValueWidget<List<Note>>(
      value: notesValue,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(notesProvider(meetingId)),
      ),
      data: (notes) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notesProvider(meetingId));
          await ref.read(notesProvider(meetingId).future);
        },
        child: notes.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: const [
                  Card(
                    child: EmptyState(
                      icon: Icons.sticky_note_2_outlined,
                      title: 'No notes yet',
                      subtitle: 'Read-only meeting notes will appear here.',
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: notes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  return _NoteTile(note: notes[index]);
                },
              ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat.yMMMd().add_jm().format(
      note.updatedAt.toLocal(),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timestamp,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            note.content.isEmpty ? '—' : note.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
