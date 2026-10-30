import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:token_game/firebase_service.dart';
import 'package:token_game/theme.dart';
import 'app_state.dart';
import 'glass_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmNuke(BuildContext context) async {
    final pinCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PokeTheme.screenDark,
        title: const Text('WIPE ALL DATA',
            style: TextStyle(
                color: PokeTheme.pokedexRed, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Warning: This will permanently delete ALL active players and ALL history. Enter Admin PIN to proceed.',
              style: TextStyle(color: Colors.white70),
            ),
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
            child: const Text('Cancel',
                style: TextStyle(color: PokeTheme.bezelGray)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: PokeTheme.pokedexRed),
            onPressed: () {
              if (pinCtrl.text == '1104') {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid PIN',
                        style: TextStyle(color: PokeTheme.dPadBlack)),
                    backgroundColor: PokeTheme.alertYellow,
                  ),
                );
              }
            },
            child: const Text('NUKE DATABASE',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        await context.read<FirebaseService>().nukeDatabase();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database completely wiped!',
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: PokeTheme.indicatorGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppState>().history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deleted History',
            style: TextStyle(color: PokeTheme.bezelGray)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: PokeTheme.bezelGray),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: PokeTheme.pokedexRed),
            tooltip: 'Wipe Database',
            onPressed: () => _confirmNuke(context),
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Text(
                'No deleted history.',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (ctx, i) {
                final p = history[i];
                final bool isManualToken = p.name.startsWith('Added Token:');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GlassCard(
                    color: Colors.grey.withOpacity(0.1),
                    widget: ListTile(
                      title: Text(
                        p.name,
                        style: TextStyle(
                            decoration: isManualToken
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                            color: PokeTheme.bezelGray),
                      ),
                      subtitle: Text('ID: ${p.regNo}',
                          style: const TextStyle(color: PokeTheme.sensorBlue)),
                      trailing: isManualToken
                          ? const Text('+1 Token',
                              style: TextStyle(
                                  color: PokeTheme.indicatorGreen,
                                  fontWeight: FontWeight.bold))
                          : Text(
                              'Ended with: ${p.bands} Bands, ${p.tokens} Tokens',
                              style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
