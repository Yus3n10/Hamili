import 'dart:convert';

import 'package:flutter/material.dart';

/// Circular avatar showing a base64 profile picture, falling back to the
/// user's initial on the brand color when none is set.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.base64, required this.fallbackInitial, this.radius = 28});

  final String? base64;
  final String fallbackInitial;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final data = base64;
    if (data != null && data.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(data)));
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: Text(
        fallbackInitial.isEmpty ? '?' : fallbackInitial[0].toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
