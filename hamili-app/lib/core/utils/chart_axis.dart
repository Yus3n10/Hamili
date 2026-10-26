// Gridline spacing for count charts: the smallest round step (1, 2, 5 x 10^n)
// that keeps the peak under four gridlines, so axis labels read as whole
// numbers instead of values like 5.56K.
double niceAxisInterval(double peak) {
  var magnitude = 1.0;
  while (true) {
    for (final factor in const [1, 2, 5]) {
      final step = factor * magnitude;
      if (peak / step < 4) return step;
    }
    magnitude *= 10;
  }
}
