import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:token_game/participant.dart';
import 'package:token_game/theme.dart';
import 'app_state.dart';
import 'firebase_service.dart';
import 'glass_card.dart';
import 'history_screen.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: PokeTheme.bezelGray),
            tooltip: 'View Deleted History',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GlassCard(
              color: PokeTheme.screenDark.withOpacity(0.4),
              widget: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat('Total', state.totalPlayers, PokeTheme.bezelGray),
                  _Stat(
                      'Active', state.activePlayers, PokeTheme.indicatorGreen),
                  _Stat('Eliminated', state.eliminatedPlayers,
                      PokeTheme.pokedexRed),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (v) => state.searchQuery = v,
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.search, color: PokeTheme.bezelGray),
                hintText: 'Search by Name or 5-Digit ID...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: PokeTheme.dPadBlack.withOpacity(0.6),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30))),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: state.visibleParticipants.length,
              itemBuilder: (ctx, i) {
                final p = state.visibleParticipants[i];
                return Dismissible(
                  key: Key(p.regNo),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: PokeTheme.pokedexRed,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (dir) => _confirmDelete(ctx, p),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: () => _showPlayerStats(ctx, p),
                      borderRadius: BorderRadius.circular(30),
                      child: GlassCard(
                        color: p.isEliminated
                            ? PokeTheme.pokedexRed.withOpacity(0.3)
                            : PokeTheme.screenDark.withOpacity(0.4),
                        widget: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: PokeTheme.dPadBlack,
                            foregroundColor: PokeTheme.bezelGray,
                            child: Text('#${i + 1}'),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(
                                fontSize: 20, color: PokeTheme.bezelGray),
                          ),
                          subtitle: Text('ID: ${p.regNo}',
                              style:
                                  const TextStyle(color: PokeTheme.sensorBlue)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${p.gamesWon} Wins',
                                  style: const TextStyle(
                                      color: PokeTheme.indicatorGreen,
                                      fontSize: 16)),
                              if (p.isEliminated)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: PokeTheme.pokedexRed,
                                      borderRadius: BorderRadius.circular(4)),
                                  child: const Text('ELIMINATED',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                )
                              else
                                Text('${p.tokens} Tokens',
                                    style: const TextStyle(
                                        color: PokeTheme.gridCyan)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  String _formatDate(String rawString) {
    try {
      bool isManual = false;
      String dateString = rawString;

      if (rawString.startsWith('MANUAL_TOKEN_')) {
        isManual = true;
        dateString = rawString.replaceFirst('MANUAL_TOKEN_', '');
      }

      final dt = DateTime.parse(dateString).toLocal();
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final min = dt.minute.toString().padLeft(2, '0');

      final formatted = '${dt.day}/${dt.month}/${dt.year} at $hour:$min $ampm';
      return isManual ? 'Manual Add: $formatted' : formatted;
    } catch (e) {
      return 'Unknown Date';
    }
  }

  Future<void> _showAddTokenPinDialog(
      BuildContext context, Participant p) async {
    final pinCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PokeTheme.screenDark,
        title: const Text('Add Manual Token',
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
                backgroundColor: PokeTheme.indicatorGreen),
            onPressed: () {
              if (pinCtrl.text == '1212') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Invalid PIN',
                        style: TextStyle(color: PokeTheme.dPadBlack)),
                    backgroundColor: PokeTheme.alertYellow));
                Navigator.pop(ctx, false);
              }
            },
            child:
                const Text('Add Token', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<FirebaseService>().addManualToken(p);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Token Added!'),
          backgroundColor: PokeTheme.indicatorGreen));
    }
  }

  void _showPlayerStats(BuildContext context, Participant p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          color: PokeTheme.screenDark.withOpacity(0.9),
          widget: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(p.name,
                  style: const TextStyle(
                      fontSize: 28,
                      color: PokeTheme.alertYellow,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              Text('ID: ${p.regNo}',
                  style: const TextStyle(
                      fontSize: 16, color: PokeTheme.sensorBlue),
                  textAlign: TextAlign.center),
              const Divider(color: PokeTheme.dPadBlack, height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat('Tokens', p.tokens, PokeTheme.gridCyan),
                  _Stat('Bands', p.bands, PokeTheme.indicatorGreen),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Stat('Played', p.gamesPlayed, Colors.white),
                  _Stat('Won', p.gamesWon, PokeTheme.indicatorGreen),
                  _Stat(
                      'Lost', p.gamesPlayed - p.gamesWon, PokeTheme.pokedexRed),
                ],
              ),
              const Divider(color: PokeTheme.dPadBlack, height: 32),
              const Text('History',
                  style: TextStyle(
                      fontSize: 18,
                      color: PokeTheme.bezelGray,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (p.winHistory.isEmpty)
                const Text('No history yet.',
                    style: TextStyle(color: Colors.white54))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: p.winHistory.length,
                    itemBuilder: (_, i) {
                      final isManual =
                          p.winHistory[i].startsWith('MANUAL_TOKEN_');
                      return ListTile(
                        dense: true,
                        leading: Icon(
                            isManual ? Icons.add_circle : Icons.emoji_events,
                            color: isManual
                                ? PokeTheme.gridCyan
                                : PokeTheme.alertYellow),
                        title: Text(_formatDate(p.winHistory[i]),
                            style: const TextStyle(color: Colors.white)),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: PokeTheme.gridCyan,
                          side: const BorderSide(color: PokeTheme.gridCyan)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddTokenPinDialog(context, p);
                      },
                      child: const Text('Add 1 Token'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: PokeTheme.pokedexRed),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, participant) {
    final pinCtrl = TextEditingController();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PokeTheme.screenDark,
        title: const Text('Confirm Deletion',
            style: TextStyle(color: PokeTheme.bezelGray)),
        content: TextField(
          controller: pinCtrl,
          decoration:
              const InputDecoration(labelText: 'Enter Admin PIN to Delete'),
          keyboardType: TextInputType.number,
          obscureText: true,
          style: const TextStyle(color: PokeTheme.bezelGray),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: PokeTheme.pokedexRed),
            onPressed: () async {
              if (pinCtrl.text == '1212') {
                await context
                    .read<FirebaseService>()
                    .deleteToHistory(participant);
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Invalid PIN',
                        style: TextStyle(color: PokeTheme.dPadBlack)),
                    backgroundColor: PokeTheme.alertYellow));
                Navigator.pop(ctx, false);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 24, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: PokeTheme.bezelGray)),
      ],
    );
  }
}
