class Peer {
  final String id;
  final String hostname;
  final String os;
  final String ip;
  final int textPort;
  final List<int> filePorts;
  final DateTime lastSeenAt;

  Peer({
    required this.id,
    required this.hostname,
    required this.os,
    required this.ip,
    required this.textPort,
    required this.filePorts,
    required this.lastSeenAt,
  });

  Peer copyWith({
    String? ip,
    int? textPort,
    List<int>? filePorts,
    DateTime? lastSeenAt,
  }) {
    return Peer(
      id: id,
      hostname: hostname,
      os: os,
      ip: ip ?? this.ip,
      textPort: textPort ?? this.textPort,
      filePorts: filePorts ?? this.filePorts,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  String toString() =>
      'Peer($hostname@$ip, id=$id, os=$os, text=$textPort, files=$filePorts)';
}
