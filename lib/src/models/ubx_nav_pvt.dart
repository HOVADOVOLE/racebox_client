
import 'dart:typed_data';
import 'ubx_message.dart';

/// Represents a UBX NAV-PVT message, with custom fields from RaceBox.
class UbxNavPvt extends UbxMessage {
  final DateTime timestamp;
  final int iTOW;
  final double lon;
  final double lat;
  final double horizAccM;
  final double speed; // m/s
  final int numSv;
  final bool validFix;
  final int fixType;
  final double? gForceX;
  final double? gForceY;
  final int? batteryLevel;
  final bool? charging;
  final Uint8List raw;

  UbxNavPvt({
    required this.timestamp,
    required this.iTOW,
    required this.lon,
    required this.lat,
    required this.horizAccM,
    required this.speed,
    required this.numSv,
    required this.validFix,
    required this.raw,
    required this.fixType,
    this.gForceX,
    this.gForceY,
    this.batteryLevel,
    this.charging,
  });

  @override
  String toString() {
    return 'UbxNavPvt{timestamp: $timestamp, lat: $lat, lon: $lon, speed: $speed, valid: $validFix}';
  }
}
