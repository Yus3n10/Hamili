import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

/// External handle so other screens can make the piggy react (e.g. a coin
/// flip when income is added). Attach it via [PiggyMascot.controller].
class PiggyMascotController {
  _PiggyMascotState? _state;

  void coinFlip() => _state?._coinFlip();
}

/// The Hami piggy-bank mascot, driven by the Rive state machine
/// ("State Machine 1", inputs "coin filp" and "eye blink").
///
/// - [coinFlipOnInit]: play a coin flip once when it loads.
/// - [blink]: blink periodically (used on the chat screen).
/// - [sleeping]: freeze mid-blink so Hami looks asleep (used when the AI
///   backend is unavailable). Best-effort — it pauses the state machine
///   just after a blink so the eyes hold half-closed.
class PiggyMascot extends StatefulWidget {
  const PiggyMascot({
    super.key,
    this.size = 130,
    this.controller,
    this.blink = false,
    this.sleeping = false,
    this.coinFlipOnInit = false,
  });

  final double size;
  final PiggyMascotController? controller;
  final bool blink;
  final bool sleeping;
  final bool coinFlipOnInit;

  @override
  State<PiggyMascot> createState() => _PiggyMascotState();
}

class _PiggyMascotState extends State<PiggyMascot> {
  StateMachineController? _sm;
  SMIInput<dynamic>? _coinInput;
  SMIInput<dynamic>? _blinkInput;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didUpdateWidget(PiggyMascot old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
    if (old.blink != widget.blink || old.sleeping != widget.sleeping) {
      _applyMode();
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    widget.controller?._state = null;
    _sm?.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(artboard, 'State Machine 1');
    if (controller == null) return;
    artboard.addController(controller);
    _sm = controller;
    _coinInput = controller.findSMI('coin filp') ?? controller.findSMI('coin flip');
    _blinkInput = controller.findSMI('eye blink') ?? controller.findSMI('blink');

    if (widget.coinFlipOnInit) {
      Future.delayed(const Duration(milliseconds: 400), _coinFlip);
    }
    _applyMode();
  }

  void _fire(SMIInput<dynamic>? input) {
    if (input == null) return;
    if (input is SMITrigger) {
      input.fire();
    } else if (input is SMIBool) {
      input.value = true;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) input.value = false;
      });
    }
  }

  void _coinFlip() => _fire(_coinInput);

  void _applyMode() {
    _blinkTimer?.cancel();
    if (widget.sleeping) {
      // Blink once, then freeze the machine so the eyes hold shut — sleepy.
      _fire(_blinkInput);
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted) _sm?.isActive = false;
      });
      return;
    }
    _sm?.isActive = true;
    if (widget.blink) {
      _blinkTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) => _fire(_blinkInput));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RiveAnimation.asset(
        'assets/rive/piggy_bank.riv',
        fit: BoxFit.contain,
        onInit: _onRiveInit,
      ),
    );
  }
}
