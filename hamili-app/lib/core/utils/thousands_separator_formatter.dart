import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final _integerFormat = NumberFormat('#,##0');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {

    var digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');


    final firstDot = digitsOnly.indexOf('.');
    if (firstDot != -1) {
      final beforeDot = digitsOnly.substring(0, firstDot + 1);
      final afterDot = digitsOnly.substring(firstDot + 1).replaceAll('.', '');

      digitsOnly = beforeDot + (afterDot.length > 2 ? afterDot.substring(0, 2) : afterDot);
    }

    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final parts = digitsOnly.split('.');
    final integerPart = parts[0].isEmpty ? '0' : parts[0];
    final formattedInteger = _integerFormat.format(int.parse(integerPart));
    final formatted = parts.length > 1 ? '$formattedInteger.${parts[1]}' : formattedInteger;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }


  static double? parseAmount(String displayText) {
    return double.tryParse(displayText.replaceAll(',', ''));
  }
}
