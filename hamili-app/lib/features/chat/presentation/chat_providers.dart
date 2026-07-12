import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_provider.dart';
import '../domain/chat_message.dart';

/// Tracks whether Hami is currently generating a reply, so the UI can
/// show a "thinking" bubble instead of leaving the user staring at
/// nothing during the round-trip to Gemini.
final chatIsRespondingProvider = StateProvider<bool>((ref) => false);

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  (ref) {
    ref.watch(sessionIdProvider);
    return ChatMessagesNotifier(ref);
  },
);

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier(this.ref) : super([]);

  final Ref ref;

  Future<void> sendMessage(String content) async {
    state = [...state, ChatMessage('user', content)];
    ref.read(chatIsRespondingProvider.notifier).state = true;

    try {
      final response = await ApiClient.instance.dio.post('/chat/message', data: {'content': content});
      state = [...state, ChatMessage('assistant', response.data['reply'] as String)];
    } catch (_) {
      state = [
        ...state,
        const ChatMessage('assistant', "Hmm, I couldn't reach my brain just now. Try again in a bit?"),
      ];
    } finally {
      ref.read(chatIsRespondingProvider.notifier).state = false;
    }
  }
}
