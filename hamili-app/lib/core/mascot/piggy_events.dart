import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented whenever something worth celebrating happens — income added,
/// a savings-goal contribution or completion. The dashboard piggy mascot
/// watches this and plays a coin flip in response.
final piggyCoinFlipProvider = StateProvider<int>((ref) => 0);
