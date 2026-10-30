import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:token_game/app_state.dart';
import 'package:token_game/firebase_service.dart';
import 'package:token_game/participant.dart';
import '../glass_card.dart';
import '../theme.dart';

enum GameMode { oneVsOne, teamRoyale, ffa }

class ConsoleScreen extends StatefulWidget {
  const ConsoleScreen({super.key});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _TeamData {
  String name;
  List<Participant> players = [];
  bool isEliminated = false;
  _TeamData(this.name);

  _TeamData clone() {
    final t = _TeamData(name);
    t.players = List.from(players);
    t.isEliminated = isEliminated;
    return t;
  }
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  GameMode _mode = GameMode.oneVsOne;
  bool _gameRunning = false;
  bool _busy = false;

  // Realtime UI State
  final _p1Ctrl = TextEditingController();
  final _p2Ctrl = TextEditingController();
  Participant? _p1;
  Participant? _p2;
  List<_TeamData> _teams = [];
  List<TextEditingController> _teamCtrls = [];
  List<Participant> _ffaPlayers = [];
  final _ffaCtrl = TextEditingController();

  // Snapshot Backups for Undo/Cancel
  Map<String, dynamic> _dbPreGameStates = {};
  GameMode _backupMode = GameMode.oneVsOne;
  Participant? _backupP1;
  Participant? _backupP2;
  List<_TeamData> _backupTeams = [];
  List<Participant> _backupFfa = [];

  String? _error;

  @override
  void initState() {
    super.initState();
    _initTeams();
  }

  void _initTeams() {
    for (var c in _teamCtrls) c.dispose();
    _teams = [_TeamData('Team A'), _TeamData('Team B')];
    _teamCtrls = [TextEditingController(), TextEditingController()];
  }

  void _recalculateTeamNames() {
    for (int i = 0; i < _teams.length; i++) {
      _teams[i].name = 'Team ${String.fromCharCode(65 + i)}';
    }
  }

  @override
  void dispose() {
    _p1Ctrl.dispose();
    _p2Ctrl.dispose();
    _ffaCtrl.dispose();
    for (var c in _teamCtrls) c.dispose();
    super.dispose();
  }

  Participant? _findPlayer(String regNo) {
    final state = context.read<AppState>();
    for (final p in state.participants) {
      if (p.regNo == regNo) return p;
    }
    return null;
  }

  void _handle1v1Input(String val, bool isPlayer1) {
    if (val.length == 5) {
      final p = _findPlayer(val);
      setState(() {
        if (p == null) {
          _error = "Player $val not found.";
          if (isPlayer1)
            _p1 = null;
          else
            _p2 = null;
        } else if (p.isEliminated) {
          _error = "Player ${p.name} is eliminated.";
          if (isPlayer1)
            _p1 = null;
          else
            _p2 = null;
        } else if (isPlayer1 && _p2?.regNo == p.regNo) {
          _error = "Player ${p.name} is already Player 2.";
          _p1 = null;
        } else if (!isPlayer1 && _p1?.regNo == p.regNo) {
          _error = "Player ${p.name} is already Player 1.";
          _p2 = null;
        } else {
          _error = null;
          if (isPlayer1)
            _p1 = p;
          else
            _p2 = p;
          FocusScope.of(context).unfocus();
        }
      });
    } else {
      setState(() {
        if (isPlayer1)
          _p1 = null;
        else
          _p2 = null;
        _error = null;
      });
    }
  }

  void _addTeam() {
    setState(() {
      _teams.add(_TeamData('Team ${String.fromCharCode(65 + _teams.length)}'));
      _teamCtrls.add(TextEditingController());
    });
  }

  void _removeTeam(int index) {
    setState(() {
      _teams.removeAt(index);
      _teamCtrls[index].dispose();
      _teamCtrls.removeAt(index);
      _recalculateTeamNames();
    });
  }

  void _handleTeamInput(String val, int teamIndex) {
    if (val.length == 5) {
      final p = _findPlayer(val);
      if (p == null) {
        setState(() => _error = "Player $val not found.");
      } else if (p.isEliminated) {
        setState(() => _error = "Player ${p.name} is eliminated.");
      } else {
        bool exists = _teams.any((t) => t.players.any((pl) => pl.regNo == val));
        if (exists) {
          setState(() => _error = "Player ${p.name} is already in a team.");
        } else {
          setState(() {
            _teams[teamIndex].players.add(p);
            _error = null;
          });
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _teamCtrls[teamIndex].clear());
        }
      }
    }
  }

  void _handleFfaInput(String val) {
    if (val.length == 5) {
      final p = _findPlayer(val);
      if (p == null) {
        setState(() => _error = "Player $val not found.");
      } else if (p.isEliminated) {
        setState(() => _error = "Player ${p.name} is eliminated.");
      } else {
        bool exists = _ffaPlayers.any((pl) => pl.regNo == val);
        if (exists) {
          setState(() => _error = "Player ${p.name} is already in FFA.");
        } else {
          setState(() {
            _ffaPlayers.add(p);
            _error = null;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _ffaCtrl.clear());
        }
      }
    }
  }

  bool get _canStart {
    if (_gameRunning || _busy) return false;
    switch (_mode) {
      case GameMode.oneVsOne:
        return _p1 != null && _p2 != null;
      case GameMode.teamRoyale:
        return _teams.where((t) => t.players.isNotEmpty).length >= 2;
      case GameMode.ffa:
        return _ffaPlayers.length >= 2;
    }
  }

  Future<void> _startGame() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Create UI Backup
      _backupMode = _mode;
      _backupP1 = _p1;
      _backupP2 = _p2;
      _backupTeams = _teams.map((t) => t.clone()).toList();
      _backupFfa = List.from(_ffaPlayers);

      final service = context.read<FirebaseService>();
      List<String> idsToDeduct = [];
      if (_mode == GameMode.oneVsOne)
        idsToDeduct = [_p1!.regNo, _p2!.regNo];
      else if (_mode == GameMode.teamRoyale)
        idsToDeduct =
            _teams.expand((t) => t.players).map((p) => p.regNo).toList();
      else if (_mode == GameMode.ffa)
        idsToDeduct = _ffaPlayers.map((p) => p.regNo).toList();

      // Store Pre-game DB Snapshot
      _dbPreGameStates = await service.startGame(idsToDeduct);
      setState(() => _gameRunning = true);
    } catch (e) {
      setState(() => _error = "Error starting game: $e");
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _cancelGame() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<FirebaseService>().restoreStates(_dbPreGameStates);
      _resetGame();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Game Cancelled. Tokens Refunded.'),
            backgroundColor: PokeTheme.indicatorGreen));
      }
    } catch (e) {
      setState(() => _error = "Error cancelling game: $e");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _showUndoPinDialog() async {
    final pinCtrl = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PokeTheme.screenDark,
        title: const Text('Confirm Undo',
            style: TextStyle(color: PokeTheme.bezelGray)),
        content: TextField(
          controller: pinCtrl,
          decoration: const InputDecoration(labelText: 'Enter Admin PIN'),
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: PokeTheme.bezelGray),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: PokeTheme.alertYellow),
            onPressed: () {
              if (pinCtrl.text == '1212') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Invalid PIN',
                        style: TextStyle(color: PokeTheme.dPadBlack)),
                    backgroundColor: PokeTheme.alertYellow));
              }
            },
            child: const Text('Undo Action',
                style: TextStyle(
                    color: PokeTheme.dPadBlack, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _awardWin(List<String> winnerIds) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = context.read<FirebaseService>();
      final dbPreWinStates = await service.awardWinners(winnerIds);

      _resetGame();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Players awarded successfully.',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            duration: const Duration(milliseconds: 2500),
            backgroundColor: PokeTheme.indicatorGreen,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: PokeTheme.dPadBlack,
              backgroundColor: PokeTheme.alertYellow,
              onPressed: () async {
                final pinCorrect = await _showUndoPinDialog();
                if (pinCorrect == true && mounted) {
                  setState(() => _busy = true);
                  try {
                    await service.restoreStates(dbPreWinStates);
                    setState(() {
                      _mode = _backupMode;
                      _p1 = _backupP1;
                      _p2 = _backupP2;
                      _teams = _backupTeams.map((t) => t.clone()).toList();
                      _ffaPlayers = List.from(_backupFfa);
                      _gameRunning = true;
                    });
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _error = "Error: $e");
    } finally {
      setState(() => _busy = false);
    }
  }

  void _resetGame() {
    setState(() {
      _gameRunning = false;
      _p1 = null;
      _p2 = null;
      _p1Ctrl.clear();
      _p2Ctrl.clear();
      _ffaPlayers.clear();
      _ffaCtrl.clear();
      _initTeams();
      _error = null;
    });
  }

  Future<void> _showGameOverPinDialog(List<String> remainingWinners) async {
    final pinCtrl = TextEditingController();
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PokeTheme.screenDark,
        title: const Text('Confirm Game Over',
            style: TextStyle(color: PokeTheme.bezelGray)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter Admin PIN to end game and award winners.',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              decoration: const InputDecoration(labelText: 'Admin PIN'),
              keyboardType: TextInputType.number,
              obscureText: true,
              style: const TextStyle(color: PokeTheme.bezelGray),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: PokeTheme.indicatorGreen),
            onPressed: () {
              if (pinCtrl.text == '1212') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Invalid PIN',
                        style: TextStyle(color: PokeTheme.dPadBlack)),
                    backgroundColor: PokeTheme.alertYellow));
              }
            },
            child: const Text('Award Winners',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (success == true) {
      await _awardWin(remainingWinners);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_gameRunning)
                SegmentedButton<GameMode>(
                  segments: const [
                    ButtonSegment(
                        value: GameMode.oneVsOne,
                        icon: Icon(Icons.person),
                        label: Text('1 v 1')),
                    ButtonSegment(
                        value: GameMode.teamRoyale,
                        icon: Icon(Icons.groups),
                        label: Text('Royale')),
                    ButtonSegment(
                        value: GameMode.ffa,
                        icon: Icon(Icons.sports_mma),
                        label: Text('FFA')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() {
                            _mode = s.first;
                            _error = null;
                          }),
                ),
              if (!_gameRunning) const SizedBox(height: 24),
              if (_mode == GameMode.oneVsOne)
                _buildIndividualMode()
              else if (_mode == GameMode.teamRoyale)
                _buildTeamMode()
              else
                _buildFfaMode(),
              if (!_gameRunning) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: _canStart
                          ? PokeTheme.sensorBlue
                          : PokeTheme.dPadBlack,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  onPressed: _canStart ? _startGame : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START GAME (-1 Token Entry)',
                      style: TextStyle(fontSize: 20)),
                ),
              ],
              if (_busy)
                const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child:
                        LinearProgressIndicator(color: PokeTheme.sensorBlue)),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: PokeTheme.alertYellow,
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: PokeTheme.dPadBlack),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: PokeTheme.dPadBlack,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              if (_gameRunning)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: PokeTheme.bezelGray,
                        side: const BorderSide(color: PokeTheme.bezelGray)),
                    onPressed: _busy ? null : _cancelGame,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Game (Tokens Refunded)'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndividualMode() {
    return GlassCard(
      color: PokeTheme.screenDark,
      widget: Column(
        children: [
          _buildPlayerInput(
            label: _p1 != null ? _p1!.name : 'Player 1 ID',
            controller: _p1Ctrl,
            player: _p1,
            onChanged: (v) => _handle1v1Input(v, true),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('VS',
                style: TextStyle(fontSize: 32, color: PokeTheme.alertYellow)),
          ),
          _buildPlayerInput(
            label: _p2 != null ? _p2!.name : 'Player 2 ID',
            controller: _p2Ctrl,
            player: _p2,
            onChanged: (v) => _handle1v1Input(v, false),
          ),
          if (_gameRunning) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: PokeTheme.indicatorGreen,
                        padding: const EdgeInsets.all(20)),
                    onPressed: _busy ? null : () => _awardWin([_p1!.regNo]),
                    icon: const Icon(Icons.emoji_events),
                    label: Text('${_p1!.name} WON',
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: PokeTheme.indicatorGreen,
                        padding: const EdgeInsets.all(20)),
                    onPressed: _busy ? null : () => _awardWin([_p2!.regNo]),
                    icon: const Icon(Icons.emoji_events),
                    label: Text('${_p2!.name} WON',
                        style: const TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildTeamMode() {
    int activeTeams = _teams.where((t) => !t.isEliminated).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_gameRunning)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: PokeTheme.gridCyan,
                  foregroundColor: Colors.white),
              onPressed: _addTeam,
              icon: const Icon(Icons.add),
              label: const Text('Add Team'),
            ),
          ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _teams.asMap().entries.map((e) {
                return SizedBox(
                  width: isWide
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth,
                  child: _buildTeamCard(e.key, activeTeams),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTeamCard(int index, int activeTeams) {
    final team = _teams[index];
    final bool isGreyedOut = team.isEliminated;

    return Opacity(
      opacity: isGreyedOut ? 0.4 : 1.0,
      child: GlassCard(
        color: PokeTheme.screenDark,
        widget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(team.name,
                    style: TextStyle(
                        fontSize: 24,
                        color: isGreyedOut
                            ? PokeTheme.pokedexRed
                            : PokeTheme.bezelGray)),
                if (!_gameRunning && _teams.length > 2)
                  IconButton(
                    icon: const Icon(Icons.delete, color: PokeTheme.pokedexRed),
                    onPressed: () => _removeTeam(index),
                  ),
                if (_gameRunning && !team.isEliminated && activeTeams > 1)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: PokeTheme.pokedexRed),
                    onPressed: _busy
                        ? null
                        : () => setState(() => team.isEliminated = true),
                    icon: const Icon(Icons.close),
                    label: const Text('Eliminate'),
                  )
                else if (_gameRunning && !team.isEliminated && activeTeams == 1)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: PokeTheme.indicatorGreen),
                    onPressed: _busy
                        ? null
                        : () => _awardWin(
                            team.players.map((p) => p.regNo).toList()),
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('AWARD WIN'),
                  )
                else if (isGreyedOut)
                  const Text('ELIMINATED',
                      style:
                          TextStyle(color: PokeTheme.pokedexRed, fontSize: 18))
              ],
            ),
            const Divider(color: PokeTheme.dPadBlack),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: team.players
                  .map((p) => Chip(
                        label: Text('${p.name} (${p.regNo})',
                            style: const TextStyle(color: Colors.white)),
                        backgroundColor: PokeTheme.dPadBlack,
                        deleteIconColor: PokeTheme.pokedexRed,
                        onDeleted: _gameRunning
                            ? null
                            : () {
                                setState(() => team.players.remove(p));
                              },
                      ))
                  .toList(),
            ),
            if (!_gameRunning) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _teamCtrls[index],
                keyboardType: TextInputType.number,
                maxLength: 5,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5)
                ],
                style:
                    const TextStyle(color: PokeTheme.sensorBlue, fontSize: 20),
                decoration: const InputDecoration(
                  labelText: 'Scan 5-Digit ID',
                  labelStyle: TextStyle(color: PokeTheme.bezelGray),
                  counterText: '',
                  prefixIcon:
                      Icon(Icons.qr_code_scanner, color: PokeTheme.bezelGray),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: PokeTheme.dPadBlack)),
                  focusedBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: PokeTheme.sensorBlue, width: 2)),
                ),
                onChanged: (v) => _handleTeamInput(v, index),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildFfaMode() {
    return GlassCard(
      color: PokeTheme.screenDark,
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Free For All (FFA)',
              style: TextStyle(fontSize: 24, color: PokeTheme.bezelGray)),
          const Divider(color: PokeTheme.dPadBlack),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _ffaPlayers
                .map((p) => Chip(
                      label: Text('${p.name} (${p.regNo})',
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: PokeTheme.dPadBlack,
                      deleteIconColor: PokeTheme.pokedexRed,
                      onDeleted: () {
                        setState(() => _ffaPlayers.remove(p));
                      },
                    ))
                .toList(),
          ),
          if (!_gameRunning) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _ffaCtrl,
              keyboardType: TextInputType.number,
              maxLength: 5,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5)
              ],
              style: const TextStyle(color: PokeTheme.sensorBlue, fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'Scan 5-Digit ID to Add',
                labelStyle: TextStyle(color: PokeTheme.bezelGray),
                counterText: '',
                prefixIcon: Icon(Icons.person_add, color: PokeTheme.bezelGray),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: PokeTheme.dPadBlack)),
                focusedBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: PokeTheme.sensorBlue, width: 2)),
              ),
              onChanged: _handleFfaInput,
            ),
          ] else ...[
            const SizedBox(height: 32),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: PokeTheme.pokedexRed,
                padding: const EdgeInsets.all(20),
              ),
              onPressed: _busy
                  ? null
                  : () => _showGameOverPinDialog(
                      _ffaPlayers.map((p) => p.regNo).toList()),
              icon: const Icon(Icons.gavel),
              label: const Text('GAME OVER (Award Remaining)',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildPlayerInput({
    required String label,
    required TextEditingController controller,
    required Participant? player,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: !_gameRunning,
      keyboardType: TextInputType.number,
      maxLength: 5,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5)
      ],
      style: TextStyle(
        color: player != null ? PokeTheme.sensorBlue : PokeTheme.bezelGray,
        fontSize: 24,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: PokeTheme.bezelGray),
        counterText: '',
        prefixIcon: player != null
            ? const Icon(Icons.check_circle, color: PokeTheme.indicatorGreen)
            : const Icon(Icons.person, color: PokeTheme.bezelGray),
        enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: PokeTheme.dPadBlack)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: PokeTheme.sensorBlue, width: 2)),
        filled: true,
        fillColor: PokeTheme.dPadBlack.withOpacity(0.5),
      ),
      onChanged: onChanged,
    );
  }
}
