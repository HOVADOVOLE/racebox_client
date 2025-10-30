
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Scans for RaceBox devices.
class RaceBoxScanner {
  /// The UUID of the UART service used by RaceBox.
  static final Guid uartServiceUuid = Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");

  /// Starts scanning for RaceBox devices.
  ///
  /// Returns a stream of [ScanResult]s.
  /// The scan will continue until the subscription to the stream is cancelled.
  Stream<List<ScanResult>> scan() {
    try {
      FlutterBluePlus.startScan(withServices: [uartServiceUuid]);
    } catch (e) {
      // Log or handle the error appropriately
      print('Error starting scan: $e');
      return Stream.error(e);
    }

    return FlutterBluePlus.scanResults.map((results) {
      return results
          .where((r) => r.device.platformName.toLowerCase().contains('racebox'))
          .toList();
    });
  }

  /// Stops the scan.
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }
}
