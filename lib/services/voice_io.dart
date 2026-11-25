import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Live speech-to-text (on the phone) and audio playback.
class VoiceIO {
  VoiceIO._();
  static final VoiceIO instance = VoiceIO._();

  final SpeechToText _stt = SpeechToText();
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _sttReady = false;
  bool _ttsReady = false;
  void Function()? _onStopped;

  bool get isListening => _stt.isListening;

  Future<bool> _initStt() async {
    if (_sttReady) return true;
    _sttReady = await _stt.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _onStopped?.call();
      },
      onError: (_) => _onStopped?.call(),
    );
    return _sttReady;
  }

  /// Starts listening. [onText] receives the words so far, live.
  /// [onStopped] fires when the phone stops listening (silence or stop()).
  Future<bool> startListening({
    required void Function(String text) onText,
    required void Function() onStopped,
  }) async {
    if (!await _initStt()) return false;
    await stopPlayback();
    _onStopped = onStopped;
    await _stt.listen(
      onResult: (r) => onText(r.recognizedWords),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
      ),
    );
    return true;
  }

  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
  }

  /// Plays an mp3 file. Completes when playback finishes or is stopped.
  Future<void> play(String filePath) async {
    await _player.stop();
    await _player.setFilePath(filePath);
    final finished = _player.processingStateStream.firstWhere(
        (s) => s == ProcessingState.completed || s == ProcessingState.idle);
    _player.play();
    await finished.timeout(const Duration(minutes: 2), onTimeout: () => ProcessingState.completed);
  }

  /// Plays a remote clip (voice previews).
  Future<void> playUrl(String url) async {
    await stopPlayback();
    await _player.setUrl(url);
    _player.play();
  }

  /// The phone's built-in voice. Used when the ElevenLabs voice is not available.
  Future<void> speakOffline(String text) async {
    if (!_ttsReady) {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-IN');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      _ttsReady = true;
    }
    await _tts.speak(text);
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    await _tts.stop();
  }
}
