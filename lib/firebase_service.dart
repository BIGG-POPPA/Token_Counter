import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:token_game/participant.dart';

class FirebaseService {
  final DatabaseReference _root = FirebaseDatabase.instance.ref();

  Stream<List<Participant>> watchParticipants() {
    return _root.child('participants').onValue.map((event) {
      final val = event.snapshot.value as Map<dynamic, dynamic>?;
      if (val == null) return [];
      return val.entries
          .map((e) => Participant.fromMap(e.key.toString(), e.value))
          .toList();
    });
  }

  Stream<List<Participant>> watchHistory() {
    return _root.child('history').onValue.map((event) {
      final val = event.snapshot.value as Map<dynamic, dynamic>?;
      if (val == null) return [];
      return val.entries
          .map((e) => Participant.fromMap(e.key.toString(), e.value))
          .toList();
    });
  }

  Future<void> register(String name, String regNo) async {
    final ref = _root.child('participants/$regNo');
    final snapshot = await ref.get();
    if (snapshot.exists) throw Exception('Registration number already exists.');

    await ref.set({
      'name': name,
      'regNo': regNo,
      'tokens': 2,
      'bands': 0,
      'gamesPlayed': 0,
      'gamesWon': 0,
      'winHistory': [],
    });
  }

  Future<Participant> getParticipant(String regNo) async {
    final snapshot = await _root.child('participants/$regNo').get();
    if (!snapshot.exists) throw Exception('Player $regNo not found.');
    return Participant.fromMap(regNo, snapshot.value as Map);
  }

  /// Atomic token deduction & play count increment. Returns previous state for Cancel.
  Future<Map<String, dynamic>> startGame(List<String> ids) async {
    Map<String, dynamic> previousStates = {};

    final result = await _root.child('participants').runTransaction((current) {
      if (current == null) return Transaction.success(current);
      final data = Map<String, dynamic>.from(current as Map);
      previousStates.clear();

      for (final id in ids) {
        if (!data.containsKey(id)) return Transaction.abort();
        final p = Map<String, dynamic>.from(data[id] as Map);
        if (p['tokens'] < 1) return Transaction.abort();

        previousStates[id] =
            Map<String, dynamic>.from(p); // Snapshot for Cancel

        p['tokens'] = p['tokens'] - 1;
        p['gamesPlayed'] = (p['gamesPlayed'] as int? ?? 0) + 1;
        data[id] = p;
      }
      return Transaction.success(data);
    });

    if (!result.committed)
      throw Exception('Failed to start game. Check if players are eliminated.');
    return previousStates;
  }

  /// Atomic reward for winners: Returns previous state for UNDO
  Future<Map<String, dynamic>> awardWinners(List<String> ids) async {
    Map<String, dynamic> previousStates = {};

    await _root.child('participants').runTransaction((current) {
      if (current == null) return Transaction.success(current);
      final data = Map<String, dynamic>.from(current as Map);
      previousStates.clear();

      for (final id in ids) {
        if (!data.containsKey(id)) continue;

        final p = Map<String, dynamic>.from(data[id] as Map);
        previousStates[id] = Map<String, dynamic>.from(p); // Snapshot for Undo

        p['gamesWon'] = (p['gamesWon'] as int? ?? 0) + 1;

        final currentBands = p['bands'] as int? ?? 0;
        if (currentBands < 2) p['bands'] = currentBands + 1;

        final currentTokens = p['tokens'] as int? ?? 0;
        p['tokens'] = math.min(currentTokens + 1, 2);

        final history = List<dynamic>.from(p['winHistory'] ?? []);
        history.add(DateTime.now().toIso8601String());
        p['winHistory'] = history;

        data[id] = p;
      }
      return Transaction.success(data);
    });

    return previousStates;
  }

  /// Restores a specific set of players to a previous state (used for Undo and Cancel)
  Future<void> restoreStates(Map<String, dynamic> previousStates) async {
    if (previousStates.isEmpty) return;

    await _root.child('participants').runTransaction((current) {
      if (current == null) return Transaction.success(current);
      final data = Map<String, dynamic>.from(current as Map);

      for (final id in previousStates.keys) {
        if (data.containsKey(id)) {
          data[id] = previousStates[id];
        }
      }
      return Transaction.success(data);
    });
  }

  Future<void> addManualToken(Participant p) async {
    await _root.child('participants/${p.regNo}').runTransaction((current) {
      if (current == null) return Transaction.success(current);
      final data = Map<String, dynamic>.from(current as Map);

      data['tokens'] = (data['tokens'] as int? ?? 0) + 1;
      final history = List<dynamic>.from(data['winHistory'] ?? []);
      history.add("MANUAL_TOKEN_${DateTime.now().toIso8601String()}");
      data['winHistory'] = history;

      return Transaction.success(data);
    });

    final logId = 'TOKEN_${DateTime.now().millisecondsSinceEpoch}';
    await _root.child('history/$logId').set({
      'name': 'Added Token: ${p.name}',
      'regNo': p.regNo,
      'tokens': 1,
      'bands': 0,
      'gamesPlayed': 0,
      'gamesWon': 0,
      'winHistory': [DateTime.now().toIso8601String()],
    });
  }

  Future<void> deleteToHistory(Participant p) async {
    final updates = {
      'participants/${p.regNo}': null,
      'history/${p.regNo}': p.toMap(),
    };
    await _root.update(updates);
  }

  Future<void> nukeDatabase() async {
    await _root.child('participants').remove();
    await _root.child('history').remove();
  }
}
