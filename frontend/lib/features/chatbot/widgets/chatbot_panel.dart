// lib/features/chatbot/widgets/chatbot_panel.dart
//
// Aşama 3.C — Chatbot kayar paneli (sağdan açılır).
//
// FAB → panel açar; panel içinde:
//   • Başlık (model adı + reset + close)
//   • Mesaj balonları (user / assistant / error / tool call indicator)
//   • Composer (text field + gönder)
//
// Servis kapalıysa (paket eksik / API key yok) tek bir bilgi balonu gösterir.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/chatbot/viewmodels/chat_viewmodel.dart';

class ChatbotPanel extends StatefulWidget {
  final VoidCallback onClose;
  const ChatbotPanel({super.key, required this.onClose});

  @override
  State<ChatbotPanel> createState() => _ChatbotPanelState();
}

class _ChatbotPanelState extends State<ChatbotPanel> {
  final _composerCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<ChatViewModel>().initStatus();
    });
  }

  @override
  void dispose() {
    _composerCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _composerCtrl.text.trim();
    if (text.isEmpty) return;
    _composerCtrl.clear();
    await context.read<ChatViewModel>().sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeViewModel>();
    final vm = context.watch<ChatViewModel>();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
          ),
          border: Border.all(
            color: Colors.purpleAccent.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            _header(theme, vm),
            const Divider(height: 1),
            Expanded(child: _messageList(theme, vm)),
            _composer(theme, vm),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeViewModel theme, ChatViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Colors.purpleAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SRRP Asistanı',
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  vm.status?.model ?? (vm.statusError ?? 'Hazırlanıyor...'),
                  style: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.85),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sohbeti Temizle',
            icon: Icon(Icons.refresh, color: theme.secondaryTextColor, size: 18),
            onPressed: vm.messages.isEmpty
                ? null
                : () => vm.clearConversation(),
          ),
          IconButton(
            tooltip: 'Kapat',
            icon: Icon(Icons.close_rounded, color: theme.secondaryTextColor),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _messageList(ThemeViewModel theme, ChatViewModel vm) {
    if (vm.status != null && !vm.isAvailable) {
      return _serviceUnavailable(theme, vm);
    }
    if (vm.messages.isEmpty) {
      return _welcome(theme);
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(12),
      itemCount: vm.messages.length + (vm.isSending ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == vm.messages.length) {
          return _typingIndicator(theme);
        }
        final m = vm.messages[i];
        return _bubble(theme, m);
      },
    );
  }

  Widget _serviceUnavailable(ThemeViewModel theme, ChatViewModel vm) {
    final reason = vm.status?.reason ?? vm.statusError ?? 'Bilinmiyor';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.power_off_rounded,
              color: Colors.orangeAccent,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'Chatbot şu an kapalı',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () => vm.initStatus(forceRefresh: true),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Yeniden Dene'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcome(ThemeViewModel theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.purpleAccent,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            'SRRP AI Asistanı',
            style: TextStyle(
              color: theme.textColor,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yatırım, harita ve senaryolar hakkında sorularını sor.',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _suggestionChip('En iyi rüzgar illeri hangileri?', theme),
          _suggestionChip('Manisa\'nın güneş skorunu söyle', theme),
          _suggestionChip('10 MW rüzgar + 5 MW güneş kursak getirisi ne olur?', theme),
        ],
      ),
    );
  }

  Widget _suggestionChip(String text, ThemeViewModel theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          _composerCtrl.text = text;
          _send();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.purpleAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.purpleAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.tips_and_updates_outlined,
                size: 13,
                color: Colors.purpleAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(ThemeViewModel theme, ChatBubble m) {
    final isUser = m.role == ChatMessageRole.user;
    final isError = m.role == ChatMessageRole.error;
    final color = isError
        ? Colors.redAccent.withValues(alpha: 0.15)
        : isUser
            ? Colors.purpleAccent.withValues(alpha: 0.15)
            : theme.backgroundColor.withValues(alpha: 0.5);
    final borderColor = isError
        ? Colors.redAccent.withValues(alpha: 0.4)
        : isUser
            ? Colors.purpleAccent.withValues(alpha: 0.45)
            : theme.secondaryTextColor.withValues(alpha: 0.2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Tool call indicator
            if (m.toolCalls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 4,
                  children: m.toolCalls
                      .map((tc) => _toolChip(tc.name))
                      .toList(),
                ),
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: SelectableText(
                  m.text,
                  style: TextStyle(
                    color: isError
                        ? Colors.redAccent
                        : theme.textColor,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.build_rounded, color: Colors.cyanAccent, size: 10),
          const SizedBox(width: 3),
          Text(
            name,
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _typingIndicator(ThemeViewModel theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
          ),
          const SizedBox(width: 8),
          Text(
            'Düşünüyor...',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(ThemeViewModel theme, ChatViewModel vm) {
    final disabled = vm.isSending || !vm.isAvailable;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _composerCtrl,
              enabled: !disabled,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: theme.textColor, fontSize: 13),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: vm.isAvailable
                    ? 'Sorunuzu yazın...'
                    : 'Servis kapalı',
                hintStyle: TextStyle(
                  color: theme.secondaryTextColor.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.secondaryTextColor.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor:
                  disabled ? Colors.grey.shade700 : Colors.purpleAccent,
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            color: Colors.white,
            onPressed: disabled ? null : _send,
          ),
        ],
      ),
    );
  }
}
