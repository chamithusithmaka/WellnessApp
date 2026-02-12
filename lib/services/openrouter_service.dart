// openrouter_service.dart - Handles communication with OpenRouter AI
// Uses OpenAI-compatible API format via OpenRouter

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  // Get API key from environment variables
  static String get _apiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';
  
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String _model = 'openai/gpt-4o-mini';

  // System prompt for emotional support bot
  static const String _systemPrompt = '''
You are Serenity, a compassionate AI wellness companion for emotional support. Be warm, empathetic, and non-judgmental like a caring friend.

Rules:
- Acknowledge feelings first using reflective listening before giving advice
- Validate emotions, never dismiss them
- Ask open-ended questions to help users explore feelings
- Suggest coping strategies when appropriate: breathing exercises, grounding (5-4-3-2-1), journaling, mindfulness
- Keep responses concise (2-3 paragraphs), use emoji sparingly (💙, 🌿)
- If someone mentions self-harm or crisis, respond with compassion and share: "Please reach out to 988 Suicide & Crisis Lifeline (call/text 988) or Crisis Text Line (text HOME to 741741)"
- You are NOT a therapist. Encourage professional help when needed. Do not diagnose or give medication advice.
- End with an invitation to keep talking
''';

  // Send message and get AI response
  static Future<String> sendMessage(
    String userMessage,
    List<Map<String, String>> conversationHistory,
  ) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        // Build messages array (OpenAI chat format)
        List<Map<String, String>> messages = [];

        // System message
        messages.add({
          'role': 'system',
          'content': _systemPrompt,
        });

        // Add conversation history (last 10 messages to save tokens)
        final historyToSend = conversationHistory.length > 10
            ? conversationHistory.sublist(conversationHistory.length - 10)
            : conversationHistory;

        for (var msg in historyToSend) {
          messages.add({
            'role': msg['role'] == 'user' ? 'user' : 'assistant',
            'content': msg['text'] ?? '',
          });
        }

        // Add current user message
        messages.add({
          'role': 'user',
          'content': userMessage,
        });

        // Build request body (OpenAI-compatible format)
        final requestBody = {
          'model': _model,
          'messages': messages,
          'temperature': 0.85,
          'top_p': 0.95,
          'max_tokens': 512,
        };

        print(
            'OpenRouter: Attempt ${attempt + 1}, sending ${messages.length} messages to $_model');

        // Make API request
        final response = await http
            .post(
              Uri.parse(_baseUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
                'HTTP-Referer': 'https://ai-wellness-app.com',
                'X-Title': 'AI Wellness Companion',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 30));

        print('OpenRouter: Response status ${response.statusCode}');

        // Handle rate limiting
        if (response.statusCode == 429) {
          print('OpenRouter: Rate limited, waiting before retry...');
          if (attempt < 2) {
            await Future.delayed(Duration(seconds: 5 * (attempt + 1)));
            continue;
          }
          throw Exception(
              'The service is busy right now. Please try again in a moment.');
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final message = choices[0]['message'];
            final content = message['content'] as String?;
            if (content != null && content.isNotEmpty) {
              return content;
            }
          }
          return "I'm here for you. Could you share that again? 💙";
        } else {
          print('OpenRouter Error: ${response.body}');
          final errorBody = jsonDecode(response.body);
          final errorMessage = errorBody['error']?['message'] ??
              errorBody['message'] ??
              'Unknown error';
          throw Exception('AI service error: $errorMessage');
        }
      } catch (e) {
        print('OpenRouterService Error (attempt ${attempt + 1}): $e');
        if (attempt == 2 || e.toString().contains('AI service error')) {
          if (e.toString().contains('AI service error') ||
              e.toString().contains('busy')) {
            rethrow;
          }
          throw Exception(
            'Unable to connect. Please check your internet and try again.',
          );
        }
        await Future.delayed(Duration(seconds: 3 * (attempt + 1)));
      }
    }
    throw Exception('Unable to get a response. Please try again.');
  }

  // Generate title locally — no API call needed
  static Future<String> generateTitle(String firstMessage) async {
    final words = firstMessage.trim().split(RegExp(r'\s+'));
    if (words.length <= 5) {
      return firstMessage.trim();
    }
    return '${words.take(5).join(' ')}...';
  }
}
