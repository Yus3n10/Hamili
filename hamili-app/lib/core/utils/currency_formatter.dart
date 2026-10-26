import 'package:intl/intl.dart';


class CurrencyFormatter {
  CurrencyFormatter._();

  static String format(double amount, {String currencyCode = 'PHP'}) {
    final symbol = _symbolFor(currencyCode);
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  // Short form for chart axes, where full amounts don't fit: ₱25K, -₱4.2K.
  static String compact(double amount, {String currencyCode = 'PHP'}) {
    final value = NumberFormat.compact().format(amount.abs());
    return '${amount < 0 ? '-' : ''}${_symbolFor(currencyCode)}$value';
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
