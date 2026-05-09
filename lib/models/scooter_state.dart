/// Immutable snapshot of the scooter's current state.
class ScooterState {
  const ScooterState({
    this.isLocked = true,
    this.batteryLevel,
    this.batteryVoltageMillivolts,
    this.ecoMode = false,
    this.autoBrakeEnabled = false,
    this.autoLockMinutes = 0,
    this.transportMode = false,
    this.firmwareVersion,
  });

  /// Whether the scooter is locked.
  final bool isLocked;

  /// Battery state-of-charge in percent (0–100), or null if unknown.
  final int? batteryLevel;

  /// Battery voltage in millivolts, or null if unknown.
  final int? batteryVoltageMillivolts;

  /// Whether eco (speed-limit) mode is active.
  final bool ecoMode;

  /// Whether automatic regenerative braking is enabled.
  final bool autoBrakeEnabled;

  /// Auto-lock delay in minutes (0 = disabled).
  final int autoLockMinutes;

  /// Whether transport / folded mode is active.
  final bool transportMode;

  /// Firmware version string reported by the scooter, or null if unknown.
  final String? firmwareVersion;

  ScooterState copyWith({
    bool? isLocked,
    int? batteryLevel,
    int? batteryVoltageMillivolts,
    bool? ecoMode,
    bool? autoBrakeEnabled,
    int? autoLockMinutes,
    bool? transportMode,
    String? firmwareVersion,
  }) {
    return ScooterState(
      isLocked: isLocked ?? this.isLocked,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryVoltageMillivolts:
          batteryVoltageMillivolts ?? this.batteryVoltageMillivolts,
      ecoMode: ecoMode ?? this.ecoMode,
      autoBrakeEnabled: autoBrakeEnabled ?? this.autoBrakeEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      transportMode: transportMode ?? this.transportMode,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
    );
  }

  @override
  String toString() => 'ScooterState('
      'isLocked: $isLocked, '
      'batteryLevel: $batteryLevel%, '
      'batteryVoltage: ${batteryVoltageMillivolts}mV, '
      'ecoMode: $ecoMode, '
      'autoBrake: $autoBrakeEnabled, '
      'autoLock: ${autoLockMinutes}min, '
      'transport: $transportMode, '
      'firmware: $firmwareVersion'
      ')';
}
