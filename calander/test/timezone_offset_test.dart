import 'package:calander/services/timezone_offset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats a UTC moment as UTC+00:00', () {
    expect(currentTimezoneOffsetLabel(DateTime.utc(2026, 1, 1)), 'UTC+00:00');
  });

  test('format matches the UTC±HH:MM shape the backend parser expects', () {
    final label = currentTimezoneOffsetLabel();
    expect(RegExp(r'^UTC[+-]\d{2}:\d{2}$').hasMatch(label), isTrue, reason: label);
  });
}
