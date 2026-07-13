import 'package:intl/intl.dart';


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
