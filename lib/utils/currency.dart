/// Mirrors ../mobile-app/src/utils/currency.ts
String formatXof(num amount) {
  final rounded = amount.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }

  final sign = rounded < 0 ? '-' : '';
  return '$sign${buffer.toString()} FCFA';
}
