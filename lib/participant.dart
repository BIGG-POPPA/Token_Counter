class Participant {
  final String name;
  final String regNo;
  final int tokens;
  final int bands;
  final int gamesPlayed;
  final int gamesWon;
  final List<String> winHistory;

  const Participant({
    required this.name,
    required this.regNo,
    required this.tokens,
    required this.bands,
    required this.gamesPlayed,
    required this.gamesWon,
    required this.winHistory,
  });

  bool get isEliminated => tokens <= 0;

  factory Participant.fromMap(String key, Map<dynamic, dynamic> map) {
    return Participant(
      name: map['name']?.toString() ?? 'Unknown',
      regNo: map['regNo']?.toString() ?? key,
      tokens: (map['tokens'] as num?)?.toInt() ?? 0,
      bands: (map['bands'] as num?)?.toInt() ?? 0,
      gamesPlayed: (map['gamesPlayed'] as num?)?.toInt() ?? 0,
      gamesWon: (map['gamesWon'] as num?)?.toInt() ?? 0,
      winHistory: (map['winHistory'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'regNo': regNo,
        'tokens': tokens,
        'bands': bands,
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'winHistory': winHistory,
      };
}
