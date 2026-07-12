import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_providers.dart';

const _suggestedPrompts = [
  'Where am I overspending?',
  'Can I afford a ₱2,000 purchase right now?',
  'How can I save ₱5,000 this month?',
  "What's my biggest expense so far?",
  'What subscriptions should I consider cancelling?',
  'How am I doing against my budgets?',
];

class HamiChatPage extends ConsumerStatefulWidget {
  const HamiChatPage({super.key});

  @override
  ConsumerState<HamiChatPage> createState() => _HamiChatPageState();
}

class _HamiChatPageState extends ConsumerState<HamiChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    ref.read(chatMessagesProvider.notifier).sendMessage(text);
    _controller.clear();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isThinking = ref.watch(chatIsRespondingProvider);

    // Auto-scroll whenever a new message arrives or the thinking bubble
    // appears/disappears — runs after the frame so the list has already
    // grown before we measure maxScrollExtent.
    ref.listen(chatMessagesProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });
    ref.listen(chatIsRespondingProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Hami')),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(onPromptTap: (prompt) => ref.read(chatMessagesProvider.notifier).sendMessage(prompt))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + (isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return const _ThinkingBubble();
                      }

                      final message = messages[index];
                      final isUser = message.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isUser
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 4),
                              bottomRight: Radius.circular(isUser ? 4 : 18),
                            ),
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(color: isUser ? Theme.of(context).colorScheme.onPrimary : null),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 240.ms)
                          .slideX(begin: isUser ? 0.12 : -0.12, end: 0, curve: Curves.easeOutCubic)
                          .scaleXY(begin: 0.96, end: 1, curve: Curves.easeOutCubic);
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Ask Hami something...'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPromptTap});

  final ValueChanged<String> onPromptTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Hi! I'm Hami 🪙 Ask me anything about your money, or try one of these:",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestedPrompts
                  .map(
                    (prompt) => ActionChip(
                      label: Text(prompt),
                      onPressed: () => onPromptTap(prompt),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 10),
            const Text('Hami is thinking...'),
          ],
        ),
      ),
    );
  }
}
