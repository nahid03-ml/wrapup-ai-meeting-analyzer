import 'package:audio_session/audio_session.dart';

class AudioSessionInit {
  const AudioSessionInit._();

  static Future<void> configure() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }
}
