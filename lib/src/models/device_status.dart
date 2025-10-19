
import 'ubx_message.dart';

/// Represents a custom RaceBox status message (0xFF, 0x04).
class DeviceStatus extends UbxMessage {
  /// Battery level in percent (0-100).
  final int batteryLevel;

  /// Whether the device is currently charging.
  final bool charging;

  DeviceStatus({
    required this.batteryLevel,
    required this.charging,
  });

  @override
  String toString() {
    return 'DeviceStatus{battery: $batteryLevel%, charging: $charging}';
  }
}
