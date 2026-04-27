import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/async_value_widget.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../application/meeting_detail_provider.dart';
import '../../../data/meeting_ai_chat.dart';

class AskAiTab extends ConsumerWidget {
  const AskAiTab({required this.meetingId, super.key});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsValue = ref.watch(chatsProvider(meetingId));

    return Column(
      children: [
        Expanded(
          child: AsyncValueWidget<List<MeetingAiChat>>(
            value: chatsValue,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ErrorView(
              message: error.toString(),
              onRetry: () => ref.invalidate(chatsProvider(meetingId)),
            ),
            data: (chats) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(chatsProvider(meetingId));
                await ref.read(chatsProvider(meetingId).future);
              },
              child: chats.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      children: const [
                        Card(
                          child: EmptyState(
                            icon: Icons.smart_toy_outlined,
                            title: 'No AI questions yet',
                            subtitle:
                                'AI chat history will appear here once the feature is enabled.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: chats.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.lg),
                      itemBuilder: (context, index) {
                        return _ChatExchange(chat: chats[index]);
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: TextField(
            enabled: false,
            decoration: InputDecoration(
              hintText: 'Ask AI — coming in Phase 7',
              prefixIcon: const Icon(Icons.smart_toy_outlined),
              suffixIcon: IconButton(
                onPressed: null,
                icon: const Icon(Icons.send_outlined),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatExchange extends StatelessWidget {
  const _ChatExchange({required this.chat});

  final MeetingAiChat chat;

  @override
  Widget build(BuildContext context) {
    final timestamp = DateFormat.yMMMd().add_jm().format(
      chat.createdAt.toLocal(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: _ChatBubble(
            text: chat.question,
            timestamp: timestamp,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: _ChatBubble(
            text: chat.answer,
            timestamp: timestamp,
            backgroundColor: AppColors.surfaceElevated,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.timestamp,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String text;
  final String timestamp;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.42)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text.isEmpty ? '—' : text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              timestamp,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
