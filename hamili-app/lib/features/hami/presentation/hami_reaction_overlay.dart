import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import 'hami_avatar.dart';
import 'hami_controller.dart';
import 'hami_events.dart';

/// True while a screen with its own Hami (the chat header) is showing, so
/// the floating one stays out of the way.
final hamiEmbeddedVisibleProvider = StateProvider<bool>((ref) => false);

/// Hami popping up in a corner to react to a money event wherever the user
/// is. Shown only while a reaction plays, never takes taps, and is announced
/// to screen readers through its caption.
class HamiReactionOverlay extends ConsumerWidget {
  const HamiReactionOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(currentUserProvider).valueOrNull != null;
    if (signedIn) ref.watch(hamiEventBridgeProvider);
    final playback = ref.watch(hamiControllerProvider);
    final hidden = ref.watch(hamiEmbeddedVisibleProvider);
    final show = signedIn && !playback.isIdle && !hidden;

    // Above the navigation bar and the budget toasts, left of the add button.
    return Positioned(
      left: 12,
      bottom: 156,
      child: SafeArea(
        child: IgnorePointer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(animation), child: child),
            ),
            child: show ? _Bubble(key: ValueKey(playback.seq), caption: playback.caption) : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, this.caption});

  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const HamiAvatar(size: 64),
          if (caption != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 170),
              child: Container(
                margin: const EdgeInsets.only(left: 4, bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Text(caption!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
