
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Represents a discovered RaceBox device.
class RaceBoxDevice {
  final BluetoothDevice bluetoothDevice;

  RaceBoxDevice(this.bluetoothDevice);

  String get name => bluetoothDevice.platformName;
  String get id => bluetoothDevice.remoteId.str;
}
