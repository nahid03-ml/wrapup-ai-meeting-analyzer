import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'android_capture_smoke_test_controller.dart';
import 'android_capture_smoke_test_state.dart';

final androidCaptureSmokeTestControllerProvider = NotifierProvider.autoDispose<
  AndroidCaptureSmokeTestController,
  AndroidCaptureSmokeTestState
>(AndroidCaptureSmokeTestController.new);
