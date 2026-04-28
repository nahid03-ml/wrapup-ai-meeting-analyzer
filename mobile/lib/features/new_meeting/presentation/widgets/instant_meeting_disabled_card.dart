import 'package:flutter/material.dart';

import 'new_meeting_choice_card.dart';

class InstantMeetingDisabledCard extends StatelessWidget {
  const InstantMeetingDisabledCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const NewMeetingChoiceCard(
      icon: Icons.mic_none_outlined,
      title: 'Start instant meeting',
      subtitle: 'Coming in Phase 6',
      enabled: false,
      trailing: Icon(Icons.lock_outline),
    );
  }
}
