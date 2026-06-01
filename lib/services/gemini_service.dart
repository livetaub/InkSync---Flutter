
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gemini AI Service — calls server-side proxy for security
class GeminiService {
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
    debugPrint(
      '[GeminiService] AI processing request - tone: $tone, text length: ${text.length}',
    );

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'gemini-proxy',
        body: {'text': text, 'tone': tone},
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'AI service error';
        debugPrint('[GeminiService] Error: $errorMsg');
        throw Exception(errorMsg);
      }

      final result = response.data['result'] as String;
      debugPrint(
        '[GeminiService] Success - response length: ${result.length}',
      );
      return result;
    } catch (e, stack) {
      debugPrint('[GeminiService] Failed: $e\nStack: $stack');
      rethrow;
    }
  }
}
