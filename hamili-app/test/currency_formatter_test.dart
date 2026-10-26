import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/core/utils/currency_formatter.dart';

void main() {
  test('compact keeps small amounts whole', () {
    expect(CurrencyFormatter.compact(0), '₱0');
    expect(CurrencyFormatter.compact(850), '₱850');
  });

  test('compact shortens thousands and millions for chart axes', () {
    expect(CurrencyFormatter.compact(25000), '₱25K');
    expect(CurrencyFormatter.compact(1500), '₱1.5K');
    expect(CurrencyFormatter.compact(2300000), '₱2.3M');
  });

  test('compact keeps the sign for negative balances', () {
    expect(CurrencyFormatter.compact(-4200), '-₱4.2K');
  });
}
