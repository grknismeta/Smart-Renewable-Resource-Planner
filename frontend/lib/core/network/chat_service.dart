// lib/core/network/chat_service.dart
//
// Aşama 3.C — AI Chatbot servis katmanı (Google Gemini backend).
//
// Backend uçları:
//   POST /chat         — mesaj gönder, yanıt al
//   POST /chat/reset   — konuşma geçmişini temizle
//   GET  /chat/status  — chatbot kullanılabilir mi (paket + API key durumu)
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:frontend/core/network/api_client.dart';

class ChatStatus {
  final bool available;
  final String reason;
  final String? model;

  const ChatStatus({
    required this.available,
    required this.reason,
    this.model,
  });

  factory ChatStatus.fromJson(Map<String, dynamic> json) {
    return ChatStatus(
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String? ?? '',
      model: json['model'] as String?,
    );
  }
}

/// Tek bir tool çağrısı kaydı (UI'da "🔧 Manisa skorunu hesaplıyor..." göstermek için).
class ChatToolCall {
  final String name;
  final Map<String, dynamic> args;
  final dynamic result;

  const ChatToolCall({required this.name, required this.args, required this.result});

  factory ChatToolCall.fromJson(Map<String, dynamic> json) {
    return ChatToolCall(
      name: json['name'] as String? ?? '',
      args: Map<String, dynamic>.from(json['args'] ?? const {}),
      result: json['result'],
    );
  }
}

class ChatResponse {
  final String sessionId;
  final String message;
  final List<ChatToolCall> toolCalls;
  final String? error;

  const ChatResponse({
    required this.sessionId,
    required this.message,
    required this.toolCalls,
    this.error,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final calls = (json['tool_calls'] as List? ?? const [])
        .map((e) => ChatToolCall.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ChatResponse(
      sessionId: json['session_id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      toolCalls: calls,
      error: json['error'] as String?,
    );
  }
}

class ChatService extends BaseService {
  ChatService(super.storageService);

  /// Sohbet durumu — UI başlangıçta bunu çağırıp "kapalı" gösterir.
  Future<ChatStatus> fetchStatus() async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/status'),
      headers: await getHeaders(),
    );
    final data = processResponse(response);
    if (data is Map<String, dynamic>) return ChatStatus.fromJson(data);
    return const ChatStatus(available: false, reason: 'Durum alınamadı');
  }

  /// Mesaj gönder — backend Gemini'ye yönlendirir, yanıt + tool call'ları döner.
  Future<ChatResponse> sendMessage({
    required String message,
    String? sessionId,
  }) async {
    final body = <String, dynamic>{'message': message};
    if (sessionId != null && sessionId.isNotEmpty) {
      body['session_id'] = sessionId;
    }
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: await getHeaders(),
      body: json.encode(body),
    );
    if (response.statusCode == 503) {
      // Servis kapalı (paket eksik / API key yok)
      String detail = 'Chatbot servisi kapalı';
      try {
        final b = json.decode(response.body);
        if (b is Map && b['detail'] is String) detail = b['detail'] as String;
      } catch (_) {}
      throw Exception(detail);
    }
    final data = processResponse(response);
    if (data is Map<String, dynamic>) return ChatResponse.fromJson(data);
    throw Exception('Geçersiz chatbot yanıtı');
  }

  /// Konuşma geçmişini temizle.
  Future<void> resetSession(String sessionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/reset?session_id=$sessionId'),
      headers: await getHeaders(),
    );
    if (response.statusCode != 200) {
      throw Exception('Sohbet sıfırlanamadı (status: ${response.statusCode})');
    }
  }
}
