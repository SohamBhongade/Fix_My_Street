import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/issue_categories.dart';
import '../models/ai_analysis_result.dart';

/// Groq-specific error thrown when the API returns a non-200 status.
class GroqException implements Exception {
  final int statusCode;
  final String userMessage;
  final String rawBody;

  const GroqException({
    required this.statusCode,
    required this.userMessage,
    required this.rawBody,
  });

  @override
  String toString() => 'GroqException($statusCode): $userMessage';
}

class AIService {
  AIService._();
  static final AIService instance = AIService._();

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // System prompt — kept in a separate role so Llama 4 treats it as an
  // authoritative instruction rather than part of the conversation.
  //
  // The category list is built from [kIssueCategories] at runtime so the
  // model can never drift out of sync with the UI's manual dropdown and
  // the volunteer-eligibility helper. If you add/remove a category, edit
  // `lib/core/issue_categories.dart` — this prompt updates automatically.
  static final String _systemPrompt = _buildSystemPrompt();

  static String _buildSystemPrompt() {
    final allowed = kIssueCategories.join(' | ');
    return 'You are a senior municipal-maintenance inspector for Ras Al '
        'Khaimah, UAE. When shown a photograph of a street or public-'
        'infrastructure issue, you respond with ONLY a valid JSON object — '
        'no markdown fences, no prose, no preamble.\n'
        '\n'
        'The JSON must have exactly three keys:\n'
        '  "category"    — string, MUST be one of EXACTLY these values '
        '(case-sensitive, copy verbatim):\n'
        '      $allowed | $kOtherCategory\n'
        '  "severity"    — integer 1–10 (1 = cosmetic, 10 = immediate '
        'danger to life)\n'
        '  "description" — string, 1–2 factual sentences, max 280 '
        'characters\n'
        '\n'
        'STRICT RULES:\n'
        '  • Do not invent, abbreviate, pluralize, or rephrase categories. '
        'Pick the single best match from the list above.\n'
        '  • If the photo does not clearly fit any listed category, return '
        '"$kOtherCategory" — never guess or fabricate a new category.\n'
        '  • Synonyms map to canonical: "trash"/"rubbish" → "Litter '
        'Accumulation"; "weeds"/"bushes" → "Overgrown Vegetation"; '
        '"streetlight"/"lamppost" → "Broken Street Lights"; "pipe '
        'burst"/"sewage" → "Broken Pipelines"; "tagging"/"spray paint" → '
        '"Graffiti".\n'
        '  • Return the JSON object only. No text outside it.';
  }

  static const String _userInstruction =
      'Analyze this street-issue photograph and return the JSON object as instructed.';

  // ---------- public API ----------

  Future<AIAnalysisResult> analyzeImage(File image) async {
    _assertKeyConfigured();

    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final headers = _buildHeaders();
    _validateHeaders(headers); // guard before network call

    final body = _buildBody(base64Image);

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: headers,
      body: body,
    );

    _handleErrorStatus(response);

    return _parseResponse(response.body);
  }

  // ---------- private helpers ----------

  void _assertKeyConfigured() {
    final key = AppConfig.groqApiKey;
    if (key.isEmpty) {
      throw StateError('Groq API key is not set.');
    }
  }

  Map<String, String> _buildHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AppConfig.groqApiKey}',
    };
  }

  // Validate required headers are present and non-empty before sending.
  void _validateHeaders(Map<String, String> headers) {
    const required = ['Content-Type', 'Authorization'];
    for (final key in required) {
      if (!headers.containsKey(key) || headers[key]!.isEmpty) {
        throw StateError('Request header "$key" is missing or empty.');
      }
    }
    if (headers['Content-Type'] != 'application/json') {
      throw StateError(
        'Content-Type must be application/json, '
        'got: ${headers["Content-Type"]}',
      );
    }
    if (!headers['Authorization']!.startsWith('Bearer ')) {
      throw StateError('Authorization header must use Bearer scheme.');
    }
  }

  String _buildBody(String base64Image) {
    return jsonEncode({
      'model': AppConfig.groqModel,
      'temperature': 0.1,
      'max_tokens': 512,
      'messages': [
        {
          'role': 'system',
          'content': _systemPrompt,
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
              },
            },
            {
              'type': 'text',
              'text': _userInstruction,
            },
          ],
        },
      ],
    });
  }

  /// Translates HTTP error codes into user-readable [GroqException]s.
  void _handleErrorStatus(http.Response response) {
    if (response.statusCode == 200) return;

    switch (response.statusCode) {
      case 400:
        throw GroqException(
          statusCode: 400,
          userMessage:
              'The AI could not process this image. '
              'Try a clearer photo or a different angle.',
          rawBody: response.body,
        );
      case 401:
        throw GroqException(
          statusCode: 401,
          userMessage: 'Invalid Groq API key. Check lib/core/config.dart.',
          rawBody: response.body,
        );
      case 429:
        throw GroqException(
          statusCode: 429,
          userMessage:
              'Rate limit reached. Wait a moment and try again.',
          rawBody: response.body,
        );
      case 503:
        throw GroqException(
          statusCode: 503,
          userMessage:
              'Groq is temporarily unavailable (high traffic). '
              'Please retry in a few seconds.',
          rawBody: response.body,
        );
      default:
        throw GroqException(
          statusCode: response.statusCode,
          userMessage:
              'Unexpected error from AI service (${response.statusCode}). '
              'Please try again.',
          rawBody: response.body,
        );
    }
  }

  AIAnalysisResult _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final content =
        ((decoded['choices'] as List?)?.first['message']['content'] as String?)
                ?.trim() ??
            '';

    return _parseContent(content);
  }

  AIAnalysisResult _parseContent(String raw) {
    var text = raw.trim();

    // Strip markdown fences — Llama 4 sometimes wraps output despite instructions.
    if (text.startsWith('```')) {
      final newline = text.indexOf('\n');
      final closing = text.lastIndexOf('```');
      if (newline != -1 && closing > newline) {
        text = text.substring(newline + 1, closing).trim();
      }
    }

    // Some models prefix with "json\n{..." without the fences.
    if (text.toLowerCase().startsWith('json')) {
      final brace = text.indexOf('{');
      if (brace != -1) text = text.substring(brace);
    }

    try {
      final json = jsonDecode(text);
      if (json is Map<String, dynamic>) {
        return AIAnalysisResult.fromJson(json);
      }
    } catch (_) {
      // fall through to fallback
    }
    return AIAnalysisResult.fallback();
  }
}
