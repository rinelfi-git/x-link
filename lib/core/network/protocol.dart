import 'dart:convert';

/// Protocole UDP : CROSSLINK|1|type|payload_json
class UdpProtocol {
  static const String prefix = 'CROSSLINK';
  static const int version = 1;

  static const String typeAnnounce = 'ANNOUNCE';
  static const String typeHeartbeat = 'HEARTBEAT';
  static const String typeLeave = 'LEAVE';

  /// Encode un message en "CROSSLINK|1|TYPE|{json}"
  static String encode(String type, Map<String, dynamic> payload) {
    return '$prefix|$version|$type|${jsonEncode(payload)}';
  }

  /// Décode un message. Retourne null si le format est invalide.
  static UdpMessage? decode(String raw) {
    final parts = raw.split('|');
    if (parts.length < 4) return null;
    if (parts[0] != prefix) return null;
    if (parts[1] != version.toString()) return null;

    final type = parts[2];
    // Le payload peut contenir des `|`, on le reconstruit
    final payloadStr = parts.sublist(3).join('|');

    try {
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      return UdpMessage(type: type, payload: payload);
    } catch (_) {
      return null;
    }
  }
}

class UdpMessage {
  final String type;
  final Map<String, dynamic> payload;

  UdpMessage({required this.type, required this.payload});
}
