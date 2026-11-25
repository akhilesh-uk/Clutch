import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

/// Minimal client for Anthropic's Messages API (Ultra Pro brain).
class Claude {
  static const _url = 'https://api.anthropic.com/v1/messages';

  /// One Messages API call. Retries briefly when the API is overloaded.
  static Future<Map<String, dynamic>> messages({
    required String system,
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    String? model,
    int maxTokens = 1024,
  }) async {
    if (!Config.hasClaude) throw Exception('Ultra Pro is not available yet.');
    final body = jsonEncode({
      'model': model ?? Config.claudeModel,
      'max_tokens': maxTokens,
      'system': system,
      'messages': messages,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
    });

    var status = 0;
    var text = '';
    for (var attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) await Future<void>.delayed(Duration(milliseconds: 700 * attempt * attempt));
      final res = await http
          .post(
            Uri.parse(_url),
            headers: {
              'x-api-key': Config.claudeKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      }
      status = res.statusCode;
      text = res.body;
      // Only overload / rate limit / server errors are worth retrying.
      if (status != 429 && status != 500 && status != 503 && status != 529) break;
    }
    String detail = text;
    try {
      detail = ((jsonDecode(text) as Map)['error'] as Map)['message'].toString();
    } catch (_) {}
    throw Exception('Something went wrong. Please try again.');
  }

  /// Plain text reply (no tools).
  static Future<String> text(String system, String prompt, {String? model, int maxTokens = 1024}) async {
    final res = await messages(
      system: system,
      model: model,
      maxTokens: maxTokens,
      messages: [
        {'role': 'user', 'content': prompt}
      ],
    );
    return joinText(res['content'] as List? ?? const []);
  }

  static String joinText(List content) => content
      .whereType<Map>()
      .where((b) => b['type'] == 'text')
      .map((b) => (b['text'] ?? '').toString())
      .join(' ')
      .trim();

  /// Pulls the first JSON object out of a reply, even if wrapped in prose.
  static Map<String, dynamic>? extractJson(String s) {
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      return jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
