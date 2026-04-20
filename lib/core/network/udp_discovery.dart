import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/peer.dart';
import 'protocol.dart';

/// Découverte des pairs sur le LAN via UDP broadcast.
///
/// Gère ANNOUNCE, HEARTBEAT, LEAVE, et Re-ANNOUNCE à la reconfiguration.
class UdpDiscovery {
  static const Duration announceInterval = Duration(seconds: 5);
  static const Duration heartbeatInterval = Duration(seconds: 3);
  static const Duration peerTimeout = Duration(seconds: 15);

  final int discoveryPort;
  final String hostname;
  final String os;

  /// ID de session unique généré au démarrage
  late final String id;

  RawDatagramSocket? _socket;
  Timer? _announceTimer;
  Timer? _heartbeatTimer;

  /// Ports TCP actuels (fournis par TextServer / FileServer)
  int _textPort = 0;
  List<int> _filePorts = const [];

  /// Liste réactive des pairs connus (clé = id)
  final Map<String, Peer> _peers = {};

  final _peersController = StreamController<List<Peer>>.broadcast();
  Stream<List<Peer>> get peersStream => _peersController.stream;
  List<Peer> get peers => _peers.values.toList(growable: false);

  UdpDiscovery({
    required this.discoveryPort,
    required this.hostname,
    required this.os,
  }) {
    id = const Uuid().v4();
  }

  /// Démarre le socket UDP et envoie un ANNOUNCE initial.
  /// Les ports TCP doivent être fournis ici (déjà ouverts par les serveurs).
  Future<void> start({
    required int textPort,
    required List<int> filePorts,
  }) async {
    _textPort = textPort;
    _filePorts = filePorts;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    _socket!.broadcastEnabled = true;

    _socket!.listen(_onUdpEvent);

    _broadcastAnnounce();
    _startAnnounce();
    _startHeartbeat();

    debugPrint('[UDP] Discovery démarré sur port $discoveryPort (id=$id)');
  }

  /// Met à jour les ports TCP et rediffuse un ANNOUNCE.
  /// Appelé quand le FileServer se reconfigure.
  void updatePorts({required int textPort, required List<int> filePorts}) {
    _textPort = textPort;
    _filePorts = filePorts;
    debugPrint('[UDP] Reconfiguration → re-ANNOUNCE');
    _broadcastAnnounce();
  }

  /// Envoie LEAVE et ferme le socket.
  Future<void> stop() async {
    _announceTimer?.cancel();
    _announceTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_socket != null) {
      _sendBroadcast(UdpProtocol.encode(UdpProtocol.typeLeave, {'id': id}));
      // Laisse le temps au paquet de partir
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _socket!.close();
      _socket = null;
    }

    await _peersController.close();
    debugPrint('[UDP] Discovery arrêté');
  }

  // ────── Interne ──────

  void _onUdpEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    final raw = String.fromCharCodes(datagram.data);
    final message = UdpProtocol.decode(raw);
    if (message == null) return;

    final senderId = message.payload['id'] as String?;
    if (senderId == null || senderId == id) {
      // Ignorer nos propres broadcasts
      return;
    }

    switch (message.type) {
      case UdpProtocol.typeAnnounce:
        _handleAnnounce(message.payload, datagram.address.address);
        break;
      case UdpProtocol.typeHeartbeat:
        _handleHeartbeat(senderId);
        break;
      case UdpProtocol.typeLeave:
        _handleLeave(senderId);
        break;
    }
  }

  void _handleAnnounce(Map<String, dynamic> payload, String sourceIp) {
    final peerId = payload['id'] as String;
    final hostname = payload['hostname'] as String? ?? 'Unknown';
    final os = payload['os'] as String? ?? 'unknown';
    final textPort = payload['text_port'] as int? ?? 0;
    final filePorts = (payload['file_ports'] as List?)?.cast<int>() ?? [];

    final existing = _peers[peerId];
    if (existing == null) {
      _peers[peerId] = Peer(
        id: peerId,
        hostname: hostname,
        os: os,
        ip: sourceIp,
        textPort: textPort,
        filePorts: filePorts,
        lastSeenAt: DateTime.now(),
      );
      debugPrint('[UDP] Nouveau pair : $hostname@$sourceIp');
    } else {
      _peers[peerId] = existing.copyWith(
        ip: sourceIp,
        textPort: textPort,
        filePorts: filePorts,
        lastSeenAt: DateTime.now(),
      );
    }
    _emitPeers();

    // Répondre en unicast à l'expéditeur
    _sendAnnounce(InternetAddress(sourceIp));
  }

  void _handleHeartbeat(String peerId) {
    final existing = _peers[peerId];
    if (existing == null) return;
    _peers[peerId] = existing.copyWith(lastSeenAt: DateTime.now());
    _emitPeers();
  }

  void _handleLeave(String peerId) {
    if (_peers.remove(peerId) != null) {
      debugPrint('[UDP] Pair parti : $peerId');
      _emitPeers();
    }
  }

  void _broadcastAnnounce() {
    _sendAnnounce(InternetAddress('255.255.255.255'));
  }

  void _sendAnnounce(InternetAddress target) {
    final payload = {
      'id': id,
      'hostname': hostname,
      'os': os,
      'text_port': _textPort,
      'file_ports': _filePorts,
    };
    final data = UdpProtocol.encode(UdpProtocol.typeAnnounce, payload);
    _socket?.send(data.codeUnits, target, discoveryPort);
  }

  void _sendBroadcast(String data) {
    _socket?.send(
      data.codeUnits,
      InternetAddress('255.255.255.255'),
      discoveryPort,
    );
  }

  void _startAnnounce() {
    _announceTimer = Timer.periodic(announceInterval, (_) {
      _broadcastAnnounce();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      _sendBroadcast(UdpProtocol.encode(UdpProtocol.typeHeartbeat, {'id': id}));
      _cleanStalePeers();
    });
  }

  void _cleanStalePeers() {
    final now = DateTime.now();
    final before = _peers.length;
    _peers.removeWhere(
      (_, peer) => now.difference(peer.lastSeenAt) > peerTimeout,
    );
    if (_peers.length != before) {
      _emitPeers();
    }
  }

  void _emitPeers() {
    _peersController.add(peers);
  }
}
