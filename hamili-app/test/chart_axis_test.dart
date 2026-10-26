import 'package:flutter_test/flutter_test.dart';
import 'package:hamili/core/utils/chart_axis.dart';

void main() {
  test('axis steps are round numbers that give about three gridlines', () {
    expect(niceAxisInterval(0), 1);
    expect(niceAxisInterval(3), 1);
    expect(niceAxisInterval(4), 2);
    expect(niceAxisInterval(11120), 5000);
    expect(niceAxisInterval(30000), 10000);
    expect(niceAxisInterval(180), 50);
  });
}
