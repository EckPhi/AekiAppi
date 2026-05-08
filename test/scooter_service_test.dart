import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:aeki_appi/models/scooter_state.dart';
import 'package:aeki_appi/services/scooter_service.dart';

void main() {
  // ── computeAuthResponse ───────────────────────────────────────────────────

  group('computeAuthResponse', () {
    test('produces a 20-byte SHA-1 digest', () {
      final challenge = List.filled(20, 0x93);
      final response = computeAuthResponse(challenge);
      expect(response.length, equals(20));
    });

    test('matches known good value from the blog-post example', () {
      // Challenge captured via Frida in the blog post.
      final challenge = Uint8List.fromList([
        0x93,
        0x2E,
        0xED,
        0x37,
        0x8C,
        0xA9,
        0x33,
        0xBB,
        0xB8,
        0x42,
        0xFB,
        0x0A,
        0xB8,
        0x6F,
        0xF0,
        0x1D,
        0x74,
        0x48,
        0xAD,
        0xF2,
      ]);
      // Expected: SHA-1(challenge ‖ 20×0xFF) from the blog post.
      final expected = Uint8List.fromList([
        0xA7,
        0x6B,
        0xBF,
        0x7D,
        0x04,
        0xCA,
        0x93,
        0x0B,
        0x78,
        0x84,
        0xF9,
        0x75,
        0x07,
        0x07,
        0x74,
        0x57,
        0x78,
        0xDE,
        0x4E,
        0xE6,
      ]);
      expect(computeAuthResponse(challenge), equals(expected));
    });

    test('uses the default key (20 × 0xFF) when no key is provided', () {
      final challenge = Uint8List(20);
      final withDefault = computeAuthResponse(challenge);
      final withExplicit = computeAuthResponse(
        challenge,
        key: List.filled(20, 0xFF),
      );
      expect(withDefault, equals(withExplicit));
    });

    test('produces a different result for a different key', () {
      final challenge = Uint8List(20);
      final defaultResult = computeAuthResponse(challenge);
      final otherResult = computeAuthResponse(
        challenge,
        key: List.filled(20, 0xAB),
      );
      expect(defaultResult, isNot(equals(otherResult)));
    });
  });

  // ── buildCommandPacket ────────────────────────────────────────────────────

  group('buildCommandPacket', () {
    test('unlock command has correct bytes', () {
      final cmd = buildCommandPacket(0x01);
      expect(
        cmd,
        equals(
          Uint8List.fromList([
            0x00,
            0xD4,
            0x00,
            0x01,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
            0x00,
          ]),
        ),
      );
    });

    test('lock command has correct bytes', () {
      final cmd = buildCommandPacket(0x02);
      expect(cmd[3], equals(0x02));
    });

    test('eco mode ON has parameter byte 0x01 at offset 7', () {
      final cmd = buildCommandPacket(0x03, parameter: 0x01);
      expect(cmd[7], equals(0x01));
    });

    test('eco mode OFF has parameter byte 0x00 at offset 7', () {
      final cmd = buildCommandPacket(0x03, parameter: 0x00);
      expect(cmd[7], equals(0x00));
    });

    test('auto-lock timer with 15 min sets offset 7 to 0x0F', () {
      final cmd = buildCommandPacket(0x06, parameter: 15);
      expect(cmd[7], equals(0x0F));
    });

    test('packet length is always 10 bytes', () {
      for (var id = 0x00; id <= 0x0F; id++) {
        expect(buildCommandPacket(id).length, equals(10));
      }
    });

    test('bytes 0, 1, 2 are always 0x00, 0xD4, 0x00', () {
      final cmd = buildCommandPacket(0x04);
      expect(cmd[0], equals(0x00));
      expect(cmd[1], equals(0xD4));
      expect(cmd[2], equals(0x00));
    });
  });

  // ── buildTransportPacket ──────────────────────────────────────────────────

  group('buildTransportPacket', () {
    test('enable packet has correct structure', () {
      final cmd = buildTransportPacket(enable: true);
      expect(
        cmd,
        equals(
          Uint8List.fromList([
            0x00,
            0xD2,
            0x1B,
            0x1E,
            0x3C,
            0x01,
            0x00,
            0x00,
            0x01,
            0x00,
          ]),
        ),
      );
    });

    test('disable packet has 0x00 at offset 8', () {
      final cmd = buildTransportPacket(enable: false);
      expect(cmd[8], equals(0x00));
    });

    test('transport packet length is 10 bytes', () {
      expect(buildTransportPacket(enable: true).length, equals(10));
      expect(buildTransportPacket(enable: false).length, equals(10));
    });

    test('transport packet uses registry 0xD2 at offset 1', () {
      expect(buildTransportPacket(enable: true)[1], equals(0xD2));
    });
  });

  // ── ScooterState ──────────────────────────────────────────────────────────

  group('ScooterState', () {
    test('default state has safe initial values', () {
      const state = ScooterState();
      expect(state.isLocked, isTrue);
      expect(state.batteryLevel, isNull);
      expect(state.ecoMode, isFalse);
      expect(state.autoBrakeEnabled, isFalse);
      expect(state.autoLockMinutes, equals(0));
      expect(state.transportMode, isFalse);
    });

    test('copyWith updates only specified fields', () {
      const original = ScooterState();
      final updated = original.copyWith(isLocked: false, batteryLevel: 80);
      expect(updated.isLocked, isFalse);
      expect(updated.batteryLevel, equals(80));
      expect(updated.ecoMode, equals(original.ecoMode));
      expect(updated.autoBrakeEnabled, equals(original.autoBrakeEnabled));
    });

    test('copyWith with no arguments returns equivalent state', () {
      const state = ScooterState(
        isLocked: false,
        batteryLevel: 55,
        ecoMode: true,
      );
      final copy = state.copyWith();
      expect(copy.isLocked, equals(state.isLocked));
      expect(copy.batteryLevel, equals(state.batteryLevel));
      expect(copy.ecoMode, equals(state.ecoMode));
    });

    test('toString contains key fields', () {
      const state = ScooterState(batteryLevel: 42, ecoMode: true);
      final str = state.toString();
      expect(str, contains('42'));
      expect(str, contains('true'));
    });
  });
}
