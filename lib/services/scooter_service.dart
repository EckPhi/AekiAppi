import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/scooter_state.dart';

// ── BLE characteristic UUIDs ──────────────────────────────────────────────────

/// Read: 20-byte random challenge value.
const _challengeUuid = '00002556-1212-efde-1523-785feabcd123';

/// Write: SHA-1 response to the challenge.
const _responseUuid = '00002557-1212-efde-1523-785feabcd123';

/// Write: 10-byte command packets.
const _commandUuid = '0000155f-1212-efde-1523-785feabcd123';

/// Notify: registry-prefixed status notifications from the scooter.
const _notifyUuid = '0000155e-1212-efde-1523-785feabcd123';

// ── Notification registry IDs ─────────────────────────────────────────────────

const _regBatteryLevel = 0x00C0;
const _regLockStatus = 0x00C1;
const _regEcoMode = 0x00C6;
const _regSettingsPack = 0x01A2;
const _regBatteryVoltage = 0x03C1;
const _regFirmwareInfo = 0xFCFC;

// ── Known device advertisement names ─────────────────────────────────────────

const _deviceNames = {'AIKE', 'AIKE_T', 'AIKE_11'};

// ── Command constants ─────────────────────────────────────────────────────────

const _cmdHeader = 0x00;
const _cmdRegistry = 0xD4;
const _transportRegistry = 0xD2;

/// Builds a standard 10-byte command packet.
///
/// Layout:
/// ```
/// [0x00, 0xD4, 0x00, commandId, 0x00, 0x00, 0x00, parameter, 0x00, 0x00]
/// ```
Uint8List buildCommandPacket(int commandId, {int parameter = 0x00}) {
  return Uint8List.fromList([
    _cmdHeader,
    _cmdRegistry,
    0x00,
    commandId,
    0x00,
    0x00,
    0x00,
    parameter,
    0x00,
    0x00,
  ]);
}

/// Builds the 10-byte transport-mode command packet.
///
/// Layout:
/// ```
/// [0x00, 0xD2, 0x1B, 0x1E, 0x3C, 0x01, 0x00, 0x00, enable ? 0x01 : 0x00, 0x00]
/// ```
Uint8List buildTransportPacket({required bool enable}) {
  return Uint8List.fromList([
    0x00,
    _transportRegistry,
    0x1B,
    0x1E,
    0x3C,
    0x01,
    0x00,
    0x00,
    enable ? 0x01 : 0x00,
    0x00,
  ]);
}

/// Computes the BLE authentication response.
///
/// The scooter challenge-response scheme: SHA-1(challenge ‖ key).
/// All known Äike T scooters ship with the default key of 20 × 0xFF.
Uint8List computeAuthResponse(List<int> challenge, {List<int>? key}) {
  final effectiveKey = key ?? List.filled(20, 0xFF);
  final input = Uint8List.fromList([...challenge, ...effectiveKey]);
  return Uint8List.fromList(sha1.convert(input).bytes);
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Manages scanning, connecting and communicating with an Äike scooter over BLE.
///
/// Exposes [scooterState] and [isConnected] for the UI, and command methods
/// for interacting with the scooter.  Implements [ChangeNotifier] so it works
/// directly with the `provider` package.
class ScooterService extends ChangeNotifier {
  ScooterService();

  // ── Public state ────────────────────────────────────────────────────────────

  ScooterState _state = const ScooterState();
  ScooterState get scooterState => _state;

  BluetoothDevice? _device;
  BluetoothDevice? get connectedDevice => _device;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _error;
  String? get error => _error;

  // ── Private fields ──────────────────────────────────────────────────────────

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  // ── Scanning ────────────────────────────────────────────────────────────────

  /// Returns a stream of discovered [BluetoothDevice]s whose advertisement
  /// name matches one of the known Äike scooter names.
  Stream<BluetoothDevice> scanForScooters({
    Duration timeout = const Duration(seconds: 10),
  }) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults
        .expand((results) => results)
        .where((result) => _deviceNames.contains(result.device.platformName))
        .map((result) => result.device);
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  // ── Connection lifecycle ────────────────────────────────────────────────────

  /// Connects to [device], runs the challenge-response authentication, and
  /// subscribes to status notifications.
  Future<void> connect(BluetoothDevice device) async {
    _setError(null);
    _isConnecting = true;
    notifyListeners();

    try {
      await device.connect(license: License.free, autoConnect: false);
      _device = device;

      _connectionSubscription = device.connectionState.listen((state) {
        final nowConnected = state == BluetoothConnectionState.connected;
        if (_isConnected != nowConnected) {
          _isConnected = nowConnected;
          if (!nowConnected) {
            _notifySubscription?.cancel();
            _notifySubscription = null;
            _state = const ScooterState();
          }
          notifyListeners();
        }
      });

      await _authenticate(device);
      await _subscribeToNotifications(device);

      _isConnected = true;
    } catch (e) {
      _setError('Connection failed: $e');
      await _cleanup();
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Disconnects from the currently connected scooter.
  Future<void> disconnect() async {
    await _cleanup();
    notifyListeners();
  }

  // ── Commands ────────────────────────────────────────────────────────────────

  /// Unlocks the scooter (command ID 0x01).
  Future<void> unlock() => _sendCommand(buildCommandPacket(0x01));

  /// Locks the scooter (command ID 0x02).
  Future<void> lock() => _sendCommand(buildCommandPacket(0x02));

  /// Enables or disables eco (speed-limit) mode (command ID 0x03).
  Future<void> setEcoMode({required bool enable}) =>
      _sendCommand(buildCommandPacket(0x03, parameter: enable ? 0x01 : 0x00));

  /// Opens the battery tray (command ID 0x04).
  Future<void> openBatteryTray() => _sendCommand(buildCommandPacket(0x04));

  /// Sets the auto-lock timer.  Pass 0 to disable (command ID 0x06).
  Future<void> setAutoLockTimer(int minutes) {
    assert(minutes >= 0 && minutes <= 255, 'minutes must be 0–255');
    return _sendCommand(buildCommandPacket(0x06, parameter: minutes));
  }

  /// Enables or disables automatic regenerative braking (command ID 0x07).
  Future<void> setAutoBrake({required bool enable}) =>
      _sendCommand(buildCommandPacket(0x07, parameter: enable ? 0x01 : 0x00));

  /// Enables or disables transport / folded mode.
  Future<void> setTransportMode({required bool enable}) =>
      _sendCommand(buildTransportPacket(enable: enable));

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _authenticate(BluetoothDevice device) async {
    final services = await device.discoverServices();

    final challengeChar = _findCharacteristic(services, _challengeUuid);
    final responseChar = _findCharacteristic(services, _responseUuid);

    final challenge = await challengeChar.read();
    final response = computeAuthResponse(challenge);
    await responseChar.write(response, withoutResponse: true);
  }

  Future<void> _subscribeToNotifications(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final notifyChar = _findCharacteristic(services, _notifyUuid);

    await notifyChar.setNotifyValue(true);
    _notifySubscription = notifyChar.onValueReceived.listen(
      _handleNotification,
    );
  }

  Future<void> _sendCommand(Uint8List packet) async {
    if (!_isConnected || _device == null) {
      _setError('Not connected to a scooter');
      return;
    }
    _setError(null);
    try {
      final services = await _device!.discoverServices();
      final cmdChar = _findCharacteristic(services, _commandUuid);
      await cmdChar.write(packet, withoutResponse: true);
    } catch (e) {
      _setError('Command failed: $e');
    }
  }

  void _handleNotification(List<int> data) {
    if (data.length < 2) return;

    final registryId = (data[0] << 8) | data[1];
    final payload = data.sublist(2);

    switch (registryId) {
      case _regBatteryLevel:
        if (payload.isNotEmpty) {
          _state = _state.copyWith(batteryLevel: payload[0].clamp(0, 100));
        }
      case _regLockStatus:
        if (payload.isNotEmpty) {
          _state = _state.copyWith(isLocked: payload[0] == 0x01);
        }
      case _regEcoMode:
        if (payload.isNotEmpty) {
          _state = _state.copyWith(ecoMode: payload[0] == 0x01);
        }
      case _regSettingsPack:
        _parseSettingsPack(payload);
      case _regBatteryVoltage:
        if (payload.length >= 2) {
          final millivolts = (payload[0] << 8) | payload[1];
          _state = _state.copyWith(batteryVoltageMillivolts: millivolts);
        }
      case _regFirmwareInfo:
        if (payload.isNotEmpty) {
          _state = _state.copyWith(
            firmwareVersion: String.fromCharCodes(payload.where((b) => b != 0)),
          );
        }
      default:
        // Unknown registry — ignore.
        break;
    }
    notifyListeners();
  }

  /// Parses the 8-byte settings pack (registry 0x01A2).
  ///
  /// Byte layout:
  /// ```
  /// [0-1] unknown
  /// [2]   auto-lock minutes (0 = disabled)
  /// [3]   auto-brake (0x01 = on)
  /// [4]   unknown
  /// [5]   eco mode (0x01 = on)
  /// [6]   transport mode (0x01 = on)
  /// [7]   unknown
  /// ```
  void _parseSettingsPack(List<int> payload) {
    if (payload.length < 8) return;
    _state = _state.copyWith(
      autoLockMinutes: payload[2],
      autoBrakeEnabled: payload[3] == 0x01,
      ecoMode: payload[5] == 0x01,
      transportMode: payload[6] == 0x01,
    );
  }

  BluetoothCharacteristic _findCharacteristic(
    List<BluetoothService> services,
    String uuid,
  ) {
    for (final service in services) {
      for (final char in service.characteristics) {
        if (char.characteristicUuid.toString().toLowerCase() ==
            uuid.toLowerCase()) {
          return char;
        }
      }
    }
    throw StateError('Characteristic $uuid not found on device');
  }

  Future<void> _cleanup() async {
    _notifySubscription?.cancel();
    _notifySubscription = null;
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _device?.disconnect();
    _device = null;
    _isConnected = false;
    _state = const ScooterState();
  }

  void _setError(String? message) {
    _error = message;
    if (message != null) notifyListeners();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
