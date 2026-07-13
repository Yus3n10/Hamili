import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';


class HamiliLogo extends StatelessWidget {
  const HamiliLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset('assets/logo/hamili_logo.svg', width: size, height: size);
  }
}


class AnimatedHamiliLogo extends StatelessWidget {
  const AnimatedHamiliLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final star = size * 0.17;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          HamiliLogo(size: size)
              .animate()
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 500.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 400.ms)
              .then()
              .shimmer(duration: 1600.ms, color: Colors.white.withValues(alpha: 0.25)),
          Positioned(
            right: size * 0.12,
            top: size * 0.12,
            child: Icon(Icons.auto_awesome, size: star, color: Colors.white)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.7, end: 1.1, duration: 1200.ms, curve: Curves.easeInOut)
                .fadeIn(duration: 600.ms),
          ),
        ],
      ),
    );
  }
}
