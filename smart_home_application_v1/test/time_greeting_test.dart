import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_application_v1/core/utils/time_greeting.dart';

void main() {
  group('Time-Aware Greeting Daypart Tests', () {
    test('04:59 -> Good night', () {
      final time = DateTime(2026, 8, 29, 4, 59);
      expect(getTimeAwareGreeting(time), 'Good night, ');
    });

    test('05:00 -> Good morning (start of morning boundary)', () {
      final time = DateTime(2026, 8, 29, 5, 0);
      expect(getTimeAwareGreeting(time), 'Good morning, ');
    });

    test('11:59 -> Good morning (end of morning boundary)', () {
      final time = DateTime(2026, 8, 29, 11, 59);
      expect(getTimeAwareGreeting(time), 'Good morning, ');
    });

    test('12:00 -> Good afternoon (start of afternoon boundary)', () {
      final time = DateTime(2026, 8, 29, 12, 0);
      expect(getTimeAwareGreeting(time), 'Good afternoon, ');
    });

    test('16:59 -> Good afternoon (end of afternoon boundary)', () {
      final time = DateTime(2026, 8, 29, 16, 59);
      expect(getTimeAwareGreeting(time), 'Good afternoon, ');
    });

    test('17:00 -> Good evening (start of evening boundary)', () {
      final time = DateTime(2026, 8, 29, 17, 0);
      expect(getTimeAwareGreeting(time), 'Good evening, ');
    });

    test('20:59 -> Good evening (end of evening boundary)', () {
      final time = DateTime(2026, 8, 29, 20, 59);
      expect(getTimeAwareGreeting(time), 'Good evening, ');
    });

    test('21:00 -> Good night (start of night boundary)', () {
      final time = DateTime(2026, 8, 29, 21, 0);
      expect(getTimeAwareGreeting(time), 'Good night, ');
    });

    test('00:00 -> Good night (midnight boundary)', () {
      final time = DateTime(2026, 8, 29, 0, 0);
      expect(getTimeAwareGreeting(time), 'Good night, ');
    });

    test('23:59 -> Good night', () {
      final time = DateTime(2026, 8, 29, 23, 59);
      expect(getTimeAwareGreeting(time), 'Good night, ');
    });
  });
}
