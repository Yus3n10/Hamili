import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_provider.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/chat_message.dart';

/// Tracks whether Hami is currently generating a reply, so the UI can
/// show a "thinking" bubble instead of leaving the user staring at
/// nothing during the round-trip to Gemini.
final chatIsRespondingProvider = StateProvider<bool>((ref) => false);

/// True when Hami's last reply was the quota-exhausted fallback — the chat
/// screen uses it to show the mascot "sleeping".
final chatServersDownProvider = StateProvider<bool>((ref) => false);

/// Signal for the chat mascot's coin animation. `seq` bumps once per completed
/// action (so repeats each fire); `reverse` plays the coin coming *out* of the
/// piggy (expense) instead of dropping *in* (income).
class CoinFlip {
  const CoinFlip(this.seq, this.reverse);
  final int seq;
  final bool reverse;
}

final hamiCoinFlipProvider = StateProvider<CoinFlip>((ref) => const CoinFlip(0, false));

/// Cheerful "ding" played when Hami adds income — trains a positive association
/// with gaining money. Reused single player; failures (e.g. web autoplay gate)
/// are swallowed so a missing sound never breaks the chat.
final AudioPlayer _dingPlayer = AudioPlayer();
Future<void> _playDing() async {
  try {
    await _dingPlayer.stop();
    await _dingPlayer.play(AssetSource('sounds/ding.wav'));
  } catch (_) {}
}

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
      final effect = response.data['effect'] as String?; // "income" / "expense" / null
      for (final area in changed) {
        switch (area) {
          case 'goals':
            ref.invalidate(goalsProvider);
          case 'budgets':
            ref.invalidate(budgetsProvider);
            ref.invalidate(budgetTransactionsProvider);
          case 'recurring':
            ref.invalidate(recurringProvider);
          case 'transactions':
            ref.invalidate(transactionsProvider);
            // A transaction change also moves budget usage and the per-budget
            // drill-down; refresh both so the Budgets tab isn't left stale.
            ref.invalidate(budgetsProvider);
            ref.invalidate(budgetTransactionsProvider);
            invalidateAnalytics(ref);
          case 'profile':
            ref.invalidate(currentUserProvider);
        }
      }
      state = [
        ...state,
        ChatMessage('assistant', response.data['reply'] as String, actionDone: changed.isNotEmpty),
      ];
      if (changed.isNotEmpty) {
        // Coin drops in for income, comes out for expense; other actions flip in.
        ref.read(hamiCoinFlipProvider.notifier).update((c) => CoinFlip(c.seq + 1, effect == 'expense'));
      }
      if (effect == 'income') {
        _playDing(); // cheerful cue for gaining money
      }
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
