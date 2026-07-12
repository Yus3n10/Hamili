import 'package:intl/intl.dart';

/// Central currency formatter. Defaults to PHP since that's Hamili's
/// primary market, but accepts the user's preferred_currency so this
/// stays correct if that ever changes.
class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {String currencyCode = 'PHP'}) {
    final symbol = _symbolFor(currencyCode);
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  static String _symbolFor(String code) {
    switch (code) {
      case 'PHP':
        return '₱';
      case 'USD':
        return '\$';
      default:
        return '$code ';
    }
  }
}
