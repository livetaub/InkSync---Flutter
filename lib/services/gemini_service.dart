import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'debug_service.dart';

/// Gemini AI Service for writing assistance
class GeminiService {
  static const String _apiUrl = AppConfig.geminiApiUrl;
  static const String _apiKey = AppConfig.geminiApiKey;

  /// Available writing tones
  static const List<Map<String, String>> tones = [
    {'id': 'proofread', 'label': 'Proofread', 'icon': '✓'},
    {'id': 'rephrase', 'label': 'Rephrase', 'icon': '🔄'},
    {'id': 'professional', 'label': 'Professional', 'icon': '💼'},
    {'id': 'friendly', 'label': 'Friendly', 'icon': '🤗'},
    {'id': 'emojify', 'label': 'Emojify', 'icon': '😊'},
    {'id': 'elaborate', 'label': 'Elaborate', 'icon': '📝'},
    {'id': 'shorten', 'label': 'Shorten', 'icon': '✂️'},
  ];

  /// Process text with AI based on selected tone
  Future<String> processText(String text, String tone) async {
    DebugService.instance.log(
      '[INFO] AI processing request - tone: $tone, text length: ${text.length}',
    );

    String prompt;

    switch (tone) {
      case 'proofread':
        prompt =
            '''Proofread and correct the following text. Fix any spelling, grammar, and punctuation errors. Keep the same tone and style. Return ONLY the corrected text without any explanations or comments.

Text: "$text"''';
        break;
      case 'rephrase':
        prompt =
            '''Rephrase the following text while keeping the same meaning. Make it clearer and more natural. Return ONLY the rephrased text without any explanations or comments.

Text: "$text"''';
        break;
      case 'emojify':
        prompt =
            '''Add relevant emojis to the following text to make it more expressive and fun. Keep the original text and just add emojis. Return ONLY the text with emojis without any explanations or comments.

Text: "$text"''';
        break;
      case 'elaborate':
        prompt =
            '''Expand and elaborate on the following text. Add more details and explanation while keeping the same meaning. Return ONLY the elaborated text without any explanations or comments.

Text: "$text"''';
        break;
      case 'shorten':
        prompt =
            '''Make the following text more concise and brief while keeping the key points. Return ONLY the shortened text without any explanations or comments.

Text: "$text"''';
        break;
      default:
        prompt =
            '''Rewrite the following text in a $tone tone. Adjust the style and wording to match the tone while keeping the same meaning. Return ONLY the rewritten text without any explanations or comments.

Text: "$text"''';
    }

    return await _invokeGemini(prompt);
  }

  /// Call Gemini API
  Future<String> _invokeGemini(String prompt) async {
    try {
      DebugService.instance.log('[INFO] Calling Gemini API...');

      final response = await http.post(
        Uri.parse('$_apiUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 8192,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE',
            },
          ],
        }),
      );

      DebugService.instance.log(
        '[INFO] Gemini API response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null) {
          DebugService.instance.log(
            '[INFO] Gemini API success - response length: ${text.length}',
          );
          return text.trim();
        }
        final errorMsg =
            'No response generated from Gemini - Response body: ${response.body}';
        DebugService.instance.log('[ERROR] $errorMsg');
        throw Exception(errorMsg);
      } else {
        DebugService.instance.log(
          '[ERROR] Gemini API error - Status: ${response.statusCode}, Body: ${response.body}',
        );
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        throw Exception(
          'Gemini API error (${response.statusCode}): $errorMessage',
        );
      }
    } catch (e, stack) {
      DebugService.instance.log(
        '[ERROR] Gemini API call failed: $e\nStack: $stack',
      );
      rethrow;
    }
  }
}
