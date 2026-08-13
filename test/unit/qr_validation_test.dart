import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QR Code Dynamic Time-Slot Validation Tests', () {
    const int slotDurationMs = 5000;

    int computeSlot(DateTime time) {
      return time.millisecondsSinceEpoch ~/ slotDurationMs;
    }

    bool isSlotValid(int codeSlot, int currentSlot, {int maxDrift = 1}) {
      return (codeSlot - currentSlot).abs() <= maxDrift;
    }

    test('Identical timestamp produces exact slot match', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final currentSlot = computeSlot(now);
      final codeSlot = currentSlot;

      expect(isSlotValid(codeSlot, currentSlot), isTrue);
    });

    test('Drift within 1 slot (±5 seconds) is accepted for network latency', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000010000);
      final currentSlot = computeSlot(now);

      expect(isSlotValid(currentSlot - 1, currentSlot), isTrue);
      expect(isSlotValid(currentSlot + 1, currentSlot), isTrue);
    });

    test('Drift of 2 or more slots (>= 10 seconds) is rejected as expired', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000010000);
      final currentSlot = computeSlot(now);

      expect(isSlotValid(currentSlot - 2, currentSlot), isFalse);
      expect(isSlotValid(currentSlot + 2, currentSlot), isFalse);
      expect(isSlotValid(currentSlot - 10, currentSlot), isFalse);
    });

    test('QR Code payload formatting and parsing', () {
      const sessionId = 'session_xyz123';
      final now = DateTime.now();
      final slot = computeSlot(now);
      final payload = '$sessionId:$slot';

      final parts = payload.split(':');
      expect(parts.length, 2);
      expect(parts[0], sessionId);

      final parsedSlot = int.tryParse(parts[1]);
      expect(parsedSlot, isNotNull);
      expect(parsedSlot, slot);
    });
  });
}
