/// Scores are stored as tenths (0-100) and shown out of 10 with one decimal:
/// 63 -> "6.3". One place, so every screen shows the same number.
String formatScore(int tenths) => (tenths.clamp(0, 100) / 10).toStringAsFixed(1);
