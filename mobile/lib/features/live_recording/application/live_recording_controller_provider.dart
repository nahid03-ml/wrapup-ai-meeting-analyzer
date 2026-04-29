import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_recording_controller.dart';
import 'live_recording_state.dart';

final liveRecordingControllerProvider =
    NotifierProvider<LiveRecordingController, LiveRecordingState>(
      LiveRecordingController.new,
    );
