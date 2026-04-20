import 'dart:async';

import '../models/transfer_state.dart';

/// Stocke tous les transferts de fichiers (upload + download) en cours.
/// Permet à l'UI d'observer leur progression en temps réel.
class TransferStore {
  final Map<String, TransferState> _transfers = {};
  final _controller = StreamController<String>.broadcast();

  /// Émet l'id du transfert qui vient de changer.
  Stream<String> get updates => _controller.stream;

  TransferState? get(String transferId) => _transfers[transferId];

  List<TransferState> get all => List.unmodifiable(_transfers.values);

  List<TransferState> forPeer(String peerId) => _transfers.values
      .where((t) => t.peerId == peerId)
      .toList(growable: false);

  void put(TransferState state) {
    _transfers[state.transferId] = state;
    _controller.add(state.transferId);
  }

  void update(
    String transferId,
    TransferState Function(TransferState current) mutator,
  ) {
    final current = _transfers[transferId];
    if (current == null) return;
    _transfers[transferId] = mutator(current);
    _controller.add(transferId);
  }

  void remove(String transferId) {
    if (_transfers.remove(transferId) != null) {
      _controller.add(transferId);
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
