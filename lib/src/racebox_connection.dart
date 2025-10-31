import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io';

/// Handles the connection to a single RaceBox device.
class RaceBoxConnection {
  final BluetoothDevice device;

  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;
  StreamController<List<int>> _dataStreamController =
      StreamController.broadcast();

  /// The stream of data from the RaceBox device.
  Stream<List<int>> get dataStream => _dataStreamController.stream;
  Stream<BluetoothConnectionState> get connectionState =>
      device.connectionState;

  BluetoothCharacteristic? get characteristic => _txCharacteristic;

  RaceBoxConnection(this.device);

  /// Connects to the device, discovers services, and finds the TX characteristic.
  /// Returns true if successful, false otherwise.
  Future<bool> connect() async {
    try {
      await device.connect(
          autoConnect: false, timeout: const Duration(seconds: 15));
      if (Platform.isAndroid) {
        await device.requestMtu(247);
        await device.requestConnectionPriority(
            connectionPriorityRequest: ConnectionPriority.high);
      }

      List<BluetoothService> services = await device.discoverServices();
      await Future.delayed(const Duration(milliseconds: 500));
      for (BluetoothService service in services) {
        if (service.uuid == Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E")) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid ==
                Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E")) {
              _txCharacteristic = characteristic;
              await _txCharacteristic!.setNotifyValue(true);
              _notificationSubscription =
                  _txCharacteristic!.lastValueStream.listen((value) {
                _dataStreamController.add(value);
              });
              return true;
            }
          }
        }
      }
      return false;
    } catch (e) {
      print('Error connecting to RaceBox: $e');
      return false;
    }
  }

  /// Disconnects from the device.
  Future<void> disconnect() async {
    try {
      await _notificationSubscription?.cancel();
      if (_txCharacteristic != null) {
        await _txCharacteristic!.setNotifyValue(false);
      }
      await device.disconnect();
    } catch (e) {
      print('Error disconnecting from RaceBox: $e');
    }
    _dataStreamController.close();
  }
}
