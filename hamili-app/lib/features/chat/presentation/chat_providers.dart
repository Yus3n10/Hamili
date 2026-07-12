import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_provider.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/chat_message.dart';

/// Tracks whether Hami is currently generating a reply, so the UI can
/// show a "thinking" bubble instead of leaving the user staring at
/// nothing during the round-trip to Gemini.
final chatIsRespondingProvider = StateProvider<bool>((ref) => false);

/// True when Hami's last reply was the quota-exhausted fallback — the chat
/// screen uses it to show the mascot "sleeping".
final chatServersDownProvider = StateProvider<bool>((ref) => false);

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
      final available = response.data['available'] as bool? ?? true;
      ref.read(chatServersDownProvider.notifier).state = !available;
      // If Hami performed an action, refresh the affected tabs so the change
      // is visible when the user navigates there.
      final changed = (response.data['changed'] as List?)?.cast<String>() ?? const [];
      for (final area in changed) {
        switch (area) {
          case 'goals':
            ref.invalidate(goalsProvider);
          case 'budgets':
            ref.invalidate(budgetsProvider);
          case 'transactions':
            ref.invalidate(transactionsProvider);
            invalidateAnalytics(ref);
          case 'profile':
            ref.invalidate(currentUserProvider);
        }
      }
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
