import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';

class ElevenLabs {
  static const _base = 'https://api.elevenlabs.io/v1';

  /// Stable string hash (String.hashCode can change between runs).
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  /// Text to speech in the cloned voice. Cached on disk, so a line that was
  /// spoken once (e.g. during rehearsal) plays instantly even offline.
  static Future<String> speak(String text, {String? voiceId}) async {
    final voice = (voiceId == null || voiceId.isEmpty) ? Config.elevenVoiceId : voiceId;
    if (!Config.hasEleven || voice.isEmpty) {
      throw Exception('Voice is not available right now.');
    }
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/tts_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/${_hash('$voice|$text')}.mp3');
    if (file.existsSync() && file.lengthSync() > 0) return file.path;

    Future<http.Response> post(String model) => http
        .post(
          Uri.parse('$_base/text-to-speech/$voice?output_format=mp3_44100_128'),
          headers: {
            'xi-api-key': Config.elevenKey,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': text,
            'model_id': model,
            'voice_settings': {'stability': 0.45, 'similarity_boost': 0.8},
          }),
        )
        .timeout(const Duration(seconds: 30));

    var res = await post(Config.elevenTtsModel);
    if (res.statusCode != 200 && Config.elevenTtsModel != 'eleven_multilingual_v2') {
      res = await post('eleven_multilingual_v2');
    }
    if (res.statusCode != 200) {
      throw Exception('Voice is not available right now.');
    }
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file.path;
  }

  /// Speech to text (Scribe). Accepts the m4a the recorder writes.
  static Future<String> transcribe(String path) async {
    if (!Config.hasEleven) throw Exception('Voice is not available right now.');

    Future<http.Response> send(String model) async {
      final req = http.MultipartRequest('POST', Uri.parse('$_base/speech-to-text'))
        ..headers['xi-api-key'] = Config.elevenKey
        ..fields['model_id'] = model
        ..files.add(await http.MultipartFile.fromPath('file', path));
      final streamed = await req.send().timeout(const Duration(seconds: 40));
      return http.Response.fromStream(streamed);
    }

    var res = await send(Config.elevenSttModel);
    if (res.statusCode != 200 && Config.elevenSttModel != 'scribe_v1') {
      res = await send('scribe_v1');
    }
    if (res.statusCode != 200) {
      throw Exception('Could not understand the recording.');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return ((json['text'] ?? '') as String).trim();
  }

  /// Voices available to this API key (needs the Voices: Read permission).
  static Future<List<ElevenVoice>> listVoices() async {
    if (!Config.hasEleven) throw Exception('Voice is not available right now.');
    final res = await http
        .get(Uri.parse('$_base/voices'), headers: {'xi-api-key': Config.elevenKey})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Could not load voices. Try again later.');
    }
    final list = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['voices'] as List? ?? const [];
    return [
      for (final v in list.whereType<Map>())
        ElevenVoice(
          id: (v['voice_id'] ?? '').toString(),
          name: (v['name'] ?? 'Voice').toString(),
          category: (v['category'] ?? '').toString(),
          description: (v['description'] ?? '').toString(),
          previewUrl: v['preview_url']?.toString(),
          labels: v['labels'] is Map
              ? (v['labels'] as Map).values.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
              : const <String>[],
        )
    ];
  }

  static String _short(String s) => s.length > 160 ? '${s.substring(0, 160)}...' : s;
}

class ElevenVoice {
  final String id;
  final String name;
  final String category;
  final String description;
  final String? previewUrl;
  final List<String> labels;
  ElevenVoice({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.previewUrl,
    required this.labels,
  });
}
