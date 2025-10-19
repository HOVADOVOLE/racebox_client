
import 'dart:typed_data';

import 'models/device_status.dart';
import 'models/ubx_message.dart';
import 'models/ubx_nav_pvt.dart';

/// Decoder for messages from RaceBox. Supports:
///  • RaceBox live frame (class 0xFF, id 0x01, len 80) -> UbxNavPvt
///  • UBX NAV-PVT          (class 0x01, id 0x07, len 92) -> UbxNavPvt
///  • RaceBox status       (class 0xFF, id 0x04) -> DeviceStatus
class RaceBoxProtocol {
  UbxMessage? decode(Uint8List packet) {
    // Basic UBX header
    if (packet.length < 8 || packet[0] != 0xB5 || packet[1] != 0x62) {
      return null;
    }

    final cls = packet[2];
    final id = packet[3];
    final len = (packet[5] << 8) | packet[4];

    // Must match the length of the entire frame
    if (packet.length != len + 8) return null;
    if (!_checkChecksum(packet)) return null;

    final p = packet.sublist(6, 6 + len);
    final bd = ByteData.sublistView(p);

    // ───────────────── RaceBox live frame (NAV-PVT) ─────────────────
    if (cls == 0xFF && id == 0x01 && len == 80) {
      return _parseRaceBoxNavPvt(p, bd);
    }

    // ───────────────── Standard UBX NAV-PVT ─────────────────
    if (cls == 0x01 && id == 0x07 && len == 92) {
      return _parseStandardNavPvt(p, bd);
    }

    // ───────────────── RaceBox status frame (Battery) ─────────────────
    if (cls == 0xFF && id == 0x04) {
      if (p.length > 4) {
        final batteryLevel = p[4];
        return DeviceStatus(batteryLevel: batteryLevel, charging: false);
      }
    }

    return null;
  }

  UbxNavPvt _parseRaceBoxNavPvt(Uint8List p, ByteData bd) {
    final ts = _buildGnssTime(
      bd.getUint16(4, Endian.little),
      p[6], p[7], p[8], p[9], p[10],
      bd.getInt32(16, Endian.little),
    );
    final int fixType = p[20];
    final bool valid = (fixType == 3) && ((p[21] & 0x01) != 0);
    final int iTOW = bd.getUint32(0, Endian.little);

    final batteryByte = p[67];
    final charging = (batteryByte & 0x80) != 0;
    final batteryLevel = batteryByte & 0x7F;

    return UbxNavPvt(
      timestamp: ts,
      iTOW: iTOW,
      lon: bd.getInt32(24, Endian.little) / 1e7,
      lat: bd.getInt32(28, Endian.little) / 1e7,
      horizAccM: bd.getUint32(40, Endian.little) / 1000.0,
      speed: bd.getInt32(48, Endian.little) / 1000.0,
      numSv: p[23],
      validFix: valid,
      raw: p,
      fixType: fixType,
      gForceX: bd.getInt16(68, Endian.little) / 1000.0,
      gForceY: bd.getInt16(70, Endian.little) / 1000.0,
      batteryLevel: batteryLevel,
      charging: charging,
    );
  }

  UbxNavPvt _parseStandardNavPvt(Uint8List p, ByteData bd) {
    final ts = _buildGnssTime(
      bd.getUint16(4, Endian.little),
      p[6], p[7], p[8], p[9], p[10],
      bd.getInt32(16, Endian.little),
    );
    final int fixType = p[20];
    final bool valid = (fixType >= 3) && ((p[21] & 0x01) != 0);
    final int iTOW = bd.getUint32(0, Endian.little);

    return UbxNavPvt(
      timestamp: ts,
      iTOW: iTOW,
      lon: bd.getInt32(24, Endian.little) / 1e7,
      lat: bd.getInt32(28, Endian.little) / 1e7,
      horizAccM: bd.getUint32(40, Endian.little) / 1000.0,
      speed: bd.getInt32(60, Endian.little) / 1000.0,
      numSv: p[23],
      validFix: valid,
      raw: p,
      fixType: fixType,
      gForceX: null,
      gForceY: null,
    );
  }

  bool _checkChecksum(Uint8List pkt) {
    int ckA = 0, ckB = 0;
    for (int i = 2; i < pkt.length - 2; i++) {
      ckA = (ckA + pkt[i]) & 0xFF;
      ckB = (ckB + ckA) & 0xFF;
    }
    return ckA == pkt[pkt.length - 2] && ckB == pkt[pkt.length - 1];
  }

  DateTime _buildGnssTime(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second,
    int nanoSigned,
  ) {
    final micro = nanoSigned ~/ 1000;
    final base = DateTime.utc(year, month, day, hour, minute, second);
    return base.add(Duration(microseconds: micro));
  }
}
