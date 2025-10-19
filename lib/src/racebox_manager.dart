
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'racebox_scanner.dart';
import 'racebox_connection.dart';
import 'racebox_protocol.dart';
import 'models/ubx_message.dart';
import 'racebox_device.dart';

/// Manages scanning, connection, and data processing for RaceBox devices.
class RaceBoxManager {
  static final RaceBoxManager _instance = RaceBoxManager._internal();

  factory RaceBoxManager() {
    return _instance;
  }

  RaceBoxManager._internal();

  final RaceBoxScanner _scanner = RaceBoxScanner();
  final RaceBoxProtocol _protocol = RaceBoxProtocol();
  RaceBoxConnection? _connection;

  RaceBoxConnection? get activeConnection => _connection;

  final StreamController<UbxMessage> _messageController = StreamController.broadcast();
  final StreamController<BluetoothConnectionState> _connectionStateController = StreamController.broadcast();

  Stream<UbxMessage> get messageStream => _messageController.stream;
  Stream<BluetoothConnectionState> get connectionStateStream => _connectionStateController.stream;

  /// Scans for RaceBox devices.
  Stream<List<RaceBoxDevice>> scan() {
    return _scanner.scan().map((results) {
      return results.map((r) => RaceBoxDevice(r.device)).toList();
    });
  }

  /// Stops the scan.
  Future<void> stopScan() async {
    await _scanner.stopScan();
  }

  /// Connects to a RaceBox device.
  Future<bool> connect(RaceBoxDevice device) async {
    _connection = RaceBoxConnection(device.bluetoothDevice);
    bool success = await _connection!.connect();
    if (success) {
      _connection!.connectionState.listen((state) {
        _connectionStateController.add(state);
      });
      _connection!.dataStream.listen((data) {
        final message = _protocol.decode(Uint8List.fromList(data));
        if (message != null) {
          _messageController.add(message);
        }
      });
    }
    return success;
  }

  /// Disconnects from the current device.
  Future<void> disconnect() async {
    await _connection?.disconnect();
    _connection = null;
  }
}
