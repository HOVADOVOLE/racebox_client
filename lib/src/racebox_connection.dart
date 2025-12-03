import 'dart:async';
import 'dart:typed_data'; // Added for Uint8List
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:io';
import 'models/ubx_message.dart'; // Added for UbxMessage
import 'racebox_protocol.dart'; // Added for RaceBoxProtocol

/// Handles the connection to a single RaceBox device.
class RaceBoxConnection {
  final BluetoothDevice device;

  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription<List<int>>? _notificationSubscription;
  final StreamController<UbxMessage> _dataStreamController =
      StreamController.broadcast();

  // Buffer pro příchozí byte stream, aby se mohly správně parsovat UBX zprávy.
  // Zprávy mohou přijít fragmentované nebo naopak v jednom balíku s více zprávami.
  final List<int> _buffer = [];

  /// The stream of data from the RaceBox device.
  Stream<UbxMessage> get dataStream => _dataStreamController.stream;
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
                _buffer.addAll(value);
                _processBuffer();
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

  /// Processes the internal buffer to extract and emit full UBX messages.
  /// Handles fragmented or batched data by continually trying to parse messages
  /// as long as enough data is available in the buffer.
  void _processBuffer() {
    while (_buffer.length >= 8) {
      // UBX messages start with 0xB5 0x62
      if (_buffer[0] != 0xB5 || _buffer[1] != 0x62) {
        // If not at the start of a message, discard the first byte and try again
        _buffer.removeAt(0);
        continue;
      }

      // Check if we have enough bytes to determine the payload length
      if (_buffer.length < 6) {
        // Need at least 6 bytes for header + payload length (cls, id, len_lsb, len_msb)
        break;
      }

      // Payload length is at index 4 (LSB) and 5 (MSB)
      final int payloadLen = (_buffer[5] << 8) | _buffer[4];
      final int totalMessageLen = payloadLen + 8; // Header (6) + Payload (len) + Checksum (2)

      // Check if the entire message is in the buffer
      if (_buffer.length < totalMessageLen) {
        break; // Not enough data for the full message, wait for more
      }

      // Extract the full message packet
      final Uint8List packet = Uint8List.fromList(_buffer.sublist(0, totalMessageLen));
      
      // Remove the processed message from the buffer
      _buffer.removeRange(0, totalMessageLen);

      // Attempt to decode the message
      final UbxMessage? message = RaceBoxProtocol().decode(packet);
      if (message != null) {
        _dataStreamController.add(message);
      }
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
    // Do NOT close _dataStreamController here, it's a broadcast stream
    // and might be listened to by multiple components. It should be closed
    // by RaceBoxManager when it's disposed.
  }
}
