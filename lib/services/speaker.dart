import '../config.dart';
import '../state/app_state.dart';
import 'eleven_labs.dart';
import 'voice_io.dart';

/// Speaks a reply. Ultra Pro uses the chosen ElevenLabs voice; Free (or any
/// voice failure) uses the phone's own voice, so CLUTCH always talks.
class Speaker {
  /// Why the last reply fell back to the phone voice (null if it did not).
  static String? lastFallbackReason;

  static Future<void> say(String text) async {
    final voice = VoiceIO.instance;
    final s = AppState.instance.settings;
    final voiceId = s.voiceId ?? Config.elevenVoiceId;
    if (s.ultra && Config.hasEleven && voiceId.isNotEmpty) {
      try {
        final path = await ElevenLabs.speak(text, voiceId: voiceId);
        lastFallbackReason = null;
        await voice.play(path);
        return;
      } catch (e) {
        final msg = '$e';
        lastFallbackReason = (msg.contains('402') || msg.contains('paid_plan'))
            ? 'That voice is not available, so CLUTCH is using the phone voice. Pick another voice in Settings.'
            : 'Using the phone voice for now.';
      }
    } else {
      lastFallbackReason = null;
    }
    await voice.speakOffline(text);
  }
}
