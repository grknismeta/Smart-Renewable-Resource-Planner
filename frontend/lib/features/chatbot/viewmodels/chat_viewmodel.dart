// lib/features/chatbot/viewmodels/chat_viewmodel.dart
//
// Aşama 3.C — Chatbot konuşma state'i.
//
// Tek session_id frontend tarafında tutulur (backend Redis'te 1 saat saklar);
// gönderme/yanıt akışı asenkron, UI ChangeNotifier ile reaktif.
import 'package:flutter/foundation.dart';

import 'package:frontend/core/network/api_service.dart';

enum ChatMessageRole { user, assistant, error, info }

class ChatBubble {
  final ChatMessageRole role;
  final String text;
  final List<ChatToolCall> toolCalls;
  final DateTime timestamp;

  ChatBubble({
    required this.role,
    required this.text,
    this.toolCalls = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatViewModel extends ChangeNotifier {
  final ApiService _apiService;

  ChatViewModel(this._apiService);

  final List<ChatBubble> _messages = [];
  String? _sessionId;
  bool _sending = false;
  ChatStatus? _status;
  String? _statusError;

  List<ChatBubble> get messages => List.unmodifiable(_messages);
  bool get isSending => _sending;
  ChatStatus? get status => _status;
  String? get statusError => _statusError;
  bool get isAvailable => _status?.available == true;

  Future<void> initStatus({bool forceRefresh = false}) async {
    if (_status != null && !forceRefresh) return;
    try {
      _status = await _apiService.chat.fetchStatus();
      _statusError = null;
    } catch (e) {
      _statusError = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    _messages.add(ChatBubble(role: ChatMessageRole.user, text: trimmed));
    _sending = true;
    notifyListeners();

    try {
      final resp = await _apiService.chat.sendMessage(
        message: trimmed,
        sessionId: _sessionId,
      );
      _sessionId = resp.sessionId.isNotEmpty ? resp.sessionId : _sessionId;

      if (resp.error != null && resp.error!.isNotEmpty) {
        _messages.add(ChatBubble(role: ChatMessageRole.error, text: resp.error!));
      } else {
        _messages.add(ChatBubble(
          role: ChatMessageRole.assistant,
          text: resp.message,
          toolCalls: resp.toolCalls,
        ));
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      _messages.add(ChatBubble(role: ChatMessageRole.error, text: msg));
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> clearConversation() async {
    final sid = _sessionId;
    _messages.clear();
    notifyListeners();
    if (sid == null) return;
    try {
      await _apiService.chat.resetSession(sid);
    } catch (e) {
      debugPrint('[ChatViewModel] reset hata: $e');
    } finally {
      _sessionId = null;
    }
  }
}
