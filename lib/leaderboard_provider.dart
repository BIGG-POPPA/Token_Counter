import 'dart:async';

import 'package:flutter/foundation.dart';

import 'firebase_service.dart';
import 'participant.dart';

/// Subscribes to the RTDB stream once and exposes derived stats, the sorted
/// list and the search-filtered view to the UI.
class LeaderboardProvider extends ChangeNotifier {
  LeaderboardProvider(this._service) {
    _sub = _service.watchParticipants().listen(
      (data) {
        _all = data;
        _error = null;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _error = 'Live connection error: $e';
        _loading = false;
        notifyListeners();
      },
    );
  }

  final FirebaseService _service;
  StreamSubscription<List<Participant>>? _sub;

  List<Participant> _all = [];
  String _query = '';
  bool _loading = true;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  int get total => _all.length;
  int get active => _all.where((p) => !p.isEliminated).length;
  int get eliminated => total - active;

  void setQuery(String q) {
    _query = q.trim().toLowerCase();
    notifyListeners();
  }

  /// Sorted by bands desc, then tokens desc; filtered by name OR ID.
  /// Eliminated players are deliberately NOT removed.
  List<Participant> get visible {
    final list = _all.where((p) {
      if (_query.isEmpty) return true;
      return p.name.toLowerCase().contains(_query) || p.regNo.contains(_query);
    }).toList()
      ..sort((a, b) {
        final byBands = b.bands.compareTo(a.bands);
        if (byBands != 0) return byBands;
        final byTokens = b.tokens.compareTo(a.tokens);
        if (byTokens != 0) return byTokens;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
