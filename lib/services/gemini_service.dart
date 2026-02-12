// gemini_service.dart - Handles communication with Google Gemini AI
// Provides emotional support chatbot functionality

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // Gemini API configuration
  static const String _apiKey = 'AIzaSyD17ae-RwygstZuWcGZSp2_vz_1A8HdXrw';
  // gemini-2.5-flash — current stable model
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  // Compact system prompt — saves tokens on every request
  static const String _systemPrompt = '''
You are Serenity, a compassionate AI wellness companion. Be warm, empathetic, non-judgmental.
Rules: Acknowledge feelings first. Validate emotions. Ask open-ended questions. Suggest coping strategies when appropriate. Keep responses concise (2-3 short paragraphs). Use emoji sparingly.
If someone mentions self-harm, share: 988 Suicide & Crisis Lifeline (call/text 988).
You are NOT a therapist. End with an invitation to keep talking.
''';

  // Send message to Gemini and get response
  static Future<String> sendMessage(
    String userMessage,
    List<Map<String, String>> conversationHistory,
  ) async {
    debugPrint('=== GEMINI SERVICE START ===');
    debugPrint('Gemini: User message: "$userMessage"');
    debugPrint('Gemini: History length: ${conversationHistory.length}');

    // Retry up to 2 times for rate limit errors
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        // Build contents array with conversation history
        List<Map<String, dynamic>> contents = [];

        // Add conversation history (last 10 messages to save tokens)
        final historyToSend = conversationHistory.length > 10
            ? conversationHistory.sublist(conversationHistory.length - 10)
            : conversationHistory;

        for (var msg in historyToSend) {
          contents.add({
            'role': msg['role'] == 'user' ? 'user' : 'model',
            'parts': [
              {'text': msg['text']}
            ],
          });
        }

        // Add current user message
        contents.add({
          'role': 'user',
          'parts': [
            {'text': userMessage}
          ],
        });

        // Build request body — disable thinking for faster responses
        final requestBody = {
          'system_instruction': {
            'parts': [
              {'text': _systemPrompt}
            ]
          },
          'contents': contents,
          'generationConfig': {
            'temperature': 0.85,
            'topP': 0.95,
            'maxOutputTokens': 512,
            // Disable thinking to get faster responses
            'thinkingConfig': {
              'thinkingBudget': 0,
            },
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_ONLY_HIGH',
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_ONLY_HIGH',
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_ONLY_HIGH',
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_ONLY_HIGH',
            },
          ],
        };

        debugPrint('Gemini: Attempt ${attempt + 1}, sending ${contents.length} content items');
        debugPrint('Gemini: Roles: ${contents.map((c) => c['role']).toList()}');

        final jsonBody = jsonEncode(requestBody);
        debugPrint('Gemini: Request size: ${jsonBody.length} chars');

        final url = '$_baseUrl?key=$_apiKey';
        debugPrint('Gemini: POST to ${'$_baseUrl?key=***'}');

        // Make API request with 60s timeout (thinking models need more time)
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonBody,
            )
            .timeout(const Duration(seconds: 60));

        debugPrint('Gemini: Response status: ${response.statusCode}');
        final bodyPreview = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;
        debugPrint('Gemini: Response preview: $bodyPreview');

        // Handle rate limiting — wait and retry
        if (response.statusCode == 429) {
          debugPrint('Gemini: RATE LIMITED (429), attempt $attempt');
          if (attempt < 2) {
            await Future.delayed(Duration(seconds: 5 * (attempt + 1)));
            continue;
          }
          throw Exception('The service is busy. Please try again in a moment.');
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          // Check if prompt was blocked
          final promptFeedback = data['promptFeedback'];
          if (promptFeedback != null) {
            final blockReason = promptFeedback['blockReason'];
            if (blockReason != null) {
              debugPrint('Gemini: Prompt BLOCKED: $blockReason');
              return "I'm here for you. Let's try a different approach — what's on your mind? 💙";
            }
          }

          final candidates = data['candidates'] as List?;
          debugPrint('Gemini: Candidates: ${candidates?.length ?? 0}');

          if (candidates != null && candidates.isNotEmpty) {
            final candidate = candidates[0];
            final finishReason = candidate['finishReason'] as String?;
            debugPrint('Gemini: Finish reason: $finishReason');

            if (finishReason == 'SAFETY') {
              return "I want to support you, but I need to be careful with my response. Could you tell me more? 💙";
            }

            final content = candidate['content'];
            final parts = content?['parts'] as List?;
            debugPrint('Gemini: Parts: ${parts?.length ?? 0}');

            if (parts != null && parts.isNotEmpty) {
              // Find the text part (skip thought parts from thinking models)
              for (var part in parts) {
                if (part is Map && part.containsKey('text') && !part.containsKey('thought')) {
                  final text = part['text'] as String?;
                  if (text != null && text.trim().isNotEmpty) {
                    debugPrint('Gemini: SUCCESS - response length: ${text.length}');
                    return text;
                  }
                }
              }
              // Fallback: just take the last part's text
              final lastText = parts.last['text'] as String?;
              if (lastText != null && lastText.trim().isNotEmpty) {
                debugPrint('Gemini: SUCCESS (fallback) - response length: ${lastText.length}');
                return lastText;
              }
            }
          }

          debugPrint('Gemini: No valid response found in body');
          return "I'm here for you. Could you share that again? 💙";
        } else {
          debugPrint('Gemini: ERROR ${response.statusCode}: ${response.body}');
          try {
            final errorBody = jsonDecode(response.body);
            final errorMessage = errorBody['error']?['message'] ?? 'Unknown error';
            throw Exception('AI service error: $errorMessage');
          } catch (e) {
            if (e.toString().contains('AI service error')) rethrow;
            throw Exception('AI service error: HTTP ${response.statusCode}');
          }
        }
      } on TimeoutException {
        debugPrint('Gemini: TIMEOUT on attempt ${attempt + 1}');
        if (attempt == 2) {
          throw Exception('Response took too long. Please try again.');
        }
      } catch (e) {
        debugPrint('Gemini: ERROR on attempt ${attempt + 1}: $e');
        debugPrint('Gemini: Error type: ${e.runtimeType}');
        if (attempt == 2 || e.toString().contains('AI service error')) {
          if (e.toString().contains('AI service error') ||
              e.toString().contains('busy') ||
              e.toString().contains('too long')) {
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

  // Generate title locally — no API call needed, saves quota
  static Future<String> generateTitle(String firstMessage) async {
    final words = firstMessage.trim().split(RegExp(r'\s+'));
    if (words.length <= 5) {
      return firstMessage.trim();
    }
    return '${words.take(5).join(' ')}...';
  }
}
