import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Formats a money input field live: typing "1000" displays as "1,000",
/// typing "1000.5" displays as "1,000.5". Commas are inserted
/// automatically and can't be typed manually — any comma the user types
/// is just stripped since the formatter re-derives them from the digits.
///
/// Use together with `parseAmount()` when reading the field's value back
/// out, since the displayed text contains commas that `double.parse`
/// can't handle directly.
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static final _integerFormat = NumberFormat('#,##0');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Strip everything except digits and a single decimal point.
    var digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');

    // Guard against multiple decimal points (keep only the first).
    final firstDot = digitsOnly.indexOf('.');
    if (firstDot != -1) {
      final beforeDot = digitsOnly.substring(0, firstDot + 1);
      final afterDot = digitsOnly.substring(firstDot + 1).replaceAll('.', '');
      // Limit to 2 decimal places, matching currency precision.
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

  /// Strips the display formatting back to a plain double for
  /// submission — call this instead of `double.tryParse` directly on a
  /// controller using this formatter.
  static double? parseAmount(String displayText) {
    return double.tryParse(displayText.replaceAll(',', ''));
  }
}
