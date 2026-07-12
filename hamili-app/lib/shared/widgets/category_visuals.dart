import 'package:flutter/material.dart';

/// Maps backend icon identifiers (see seed.py) to Flutter icons and a
/// consistent accent color per category. Central mapping means adding a
/// new category later means one entry here, not scattered switch cases.
class CategoryVisuals {
  CategoryVisuals._();

  static final Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt': Icons.receipt,
    'movie': Icons.movie,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'category': Icons.category,
    'payments': Icons.payments,
    'wallet': Icons.account_balance_wallet,
    'work': Icons.work,
    'trending_up': Icons.trending_up,
  };

  static IconData iconFor(String? iconKey) => _icons[iconKey] ?? Icons.category;
}
