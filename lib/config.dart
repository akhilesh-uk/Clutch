/// Keys and model names are passed in at run time, never written in code:
///   flutter run --dart-define-from-file=keys.json
class Config {
  static const geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const geminiModel =
      String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-3.8-flash');

  static const elevenKey = String.fromEnvironment('ELEVEN_API_KEY');
  static const elevenVoiceId = String.fromEnvironment('ELEVEN_VOICE_ID');
  static const elevenTtsModel =
      String.fromEnvironment('ELEVEN_TTS_MODEL', defaultValue: 'eleven_flash_v2_5');
  static const elevenSttModel =
      String.fromEnvironment('ELEVEN_STT_MODEL', defaultValue: 'scribe_v2');

  static const claudeKey = String.fromEnvironment('CLAUDE_API_KEY');
  static const claudeModel =
      String.fromEnvironment('CLAUDE_MODEL', defaultValue: 'claude-sonnet-5-5');
  static const claudeFastModel =
      String.fromEnvironment('CLAUDE_FAST_MODEL', defaultValue: 'claude-haiku-5-5');

  static bool get hasGemini => geminiKey.isNotEmpty;
  static bool get hasClaude => claudeKey.isNotEmpty;
  static bool get hasEleven => elevenKey.isNotEmpty;
  static bool get hasVoice => elevenKey.isNotEmpty && elevenVoiceId.isNotEmpty;
}
