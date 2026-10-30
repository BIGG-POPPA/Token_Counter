import 'dart:async';
import 'package:flutter/material.dart';
import 'firebase_service.dart';
import 'participant.dart';

class AppState extends ChangeNotifier {
  final FirebaseService _service;

  List<Participant> participants = [];
  List<Participant> history = [];

  String _searchQuery = '';
  String get searchQuery => _searchQuery;
  set searchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  StreamSubscription? _pSub;
  StreamSubscription? _hSub;

  AppState(this._service) {
    _pSub = _service.watchParticipants().listen((data) {
      participants = data;
      notifyListeners();
    });
    _hSub = _service.watchHistory().listen((data) {
      history = data;
      notifyListeners();
    });
  }

  int get totalPlayers => participants.length;
  int get activePlayers => participants.where((p) => !p.isEliminated).length;
  int get eliminatedPlayers => totalPlayers - activePlayers;

  List<Participant> get visibleParticipants {
    final q = _searchQuery.toLowerCase();
    final list = participants
        .where((p) => p.name.toLowerCase().contains(q) || p.regNo.contains(q))
        .toList();

    // SORT BY: Games Won > Bands > Tokens
    list.sort((a, b) {
      final byWins = b.gamesWon.compareTo(a.gamesWon);
      if (byWins != 0) return byWins;
      final byBands = b.bands.compareTo(a.bands);
      if (byBands != 0) return byBands;
      return b.tokens.compareTo(a.tokens);
    });
    return list;
  }

  @override
  void dispose() {
    _pSub?.cancel();
    _hSub?.cancel();
    super.dispose();
  }
}
