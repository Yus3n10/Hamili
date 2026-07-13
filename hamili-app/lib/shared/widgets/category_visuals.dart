import 'package:flutter/material.dart';


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
