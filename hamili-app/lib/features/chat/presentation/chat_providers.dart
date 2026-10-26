import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/offline_queue.dart';
import '../../../core/session/session_provider.dart';
import '../../analytics/presentation/analytics_providers.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../budgets/presentation/budget_providers.dart';
import '../../goals/presentation/goal_providers.dart';
import '../../hami/domain/hami_reaction.dart';
import '../../hami/presentation/hami_controller.dart';
import '../../hami/presentation/hami_events.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../domain/chat_message.dart';


final chatIsRespondingProvider = StateProvider<bool>((ref) => false);


final chatServersDownProvider = StateProvider<bool>((ref) => false);


class CoinFlip {
  const CoinFlip(this.seq, this.reverse);
  final int seq;
  final bool reverse;
}

final hamiCoinFlipProvider = StateProvider<CoinFlip>((ref) => const CoinFlip(0, false));


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


      final changed = (response.data['changed'] as List?)?.cast<String>() ?? const [];
      final effect = response.data['effect'] as String?;
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

        ref.read(hamiCoinFlipProvider.notifier).update((c) => CoinFlip(c.seq + 1, effect == 'expense'));
      }
      if (effect == 'income') {
        _playDing();
      }
      _reactToReply(response.data['answer'] as String?, effect, changed.isNotEmpty);
    } on DioException catch (e) {
      final offline = OfflineQueue.isConnectionError(e);
      state = [
        ...state,
        ChatMessage(
          'assistant',
          offline
              ? "I need a connection to chat. Your transactions, budgets, and goals still work offline, and I'll be here when you're back online."
              : "Hmm, I couldn't reach my brain just now. Try again in a bit?",
        ),
      ];
    } catch (_) {
      state = [
        ...state,
        const ChatMessage('assistant', "Hmm, I couldn't reach my brain just now. Try again in a bit?"),
      ];
    } finally {
      ref.read(chatIsRespondingProvider.notifier).state = false;
    }
  }

  // Hami's gesture comes from the reply's typed `answer` and `effect`
  // fields, never from words in the text, so "No worries" stays a plain
  // reply. Effects only count when the server says the action went through.
  void _reactToReply(String? answer, String? effect, bool actionDone) {
    final reaction = HamiReaction.forChatReply(answer: answer, effect: effect, actionDone: actionDone);
    if (reaction != null) {
      ref.read(hamiControllerProvider.notifier).play(reaction);
    } else if (actionDone && effect == 'expense') {
      hamiOnSpending(ref);
    }
  }
}
