import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:token_game/app_state.dart';
import 'package:token_game/console_screen.dart';
import 'package:token_game/firebase_service.dart';
import 'package:token_game/leaderboard_screen.dart';
import 'package:token_game/registration_screen.dart';

import 'firebase_options.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TokenGameApp());
}

class TokenGameApp extends StatelessWidget {
  const TokenGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirebaseService>(create: (_) => FirebaseService()),
        ChangeNotifierProxyProvider<FirebaseService, AppState>(
          create: (ctx) => AppState(ctx.read<FirebaseService>()),
          update: (_, service, state) => state ?? AppState(service),
        ),
      ],
      child: MaterialApp(
        title: 'Token Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: PokeTheme.pokedexRed,
          colorScheme: const ColorScheme.dark(
            primary: PokeTheme.sensorBlue,
            secondary: PokeTheme.gridCyan,
            surface: PokeTheme.screenDark,
            error: PokeTheme.alertYellow,
          ),
          // CHANGED: Applied Rubik Bubbles globally
          textTheme:
              GoogleFonts.rubikBubblesTextTheme(Theme.of(context).textTheme)
                  .apply(
                    bodyColor: PokeTheme.bezelGray,
                    displayColor: PokeTheme.bezelGray,
                  ),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    RegistrationScreen(),
    ConsoleScreen(),
    LeaderboardScreen(),
  ];

  static const _destinations = [
    (Icons.person_add, 'Register'),
    (Icons.gamepad, 'Console'),
    (Icons.leaderboard, 'Leaderboard'),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;
    final body = IndexedStack(index: _index, children: _pages);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _destinations[_index].$2,
          style: const TextStyle(color: PokeTheme.bezelGray, fontSize: 24),
        ),
        backgroundColor: PokeTheme.pokedexRed,
        elevation: 0,
        iconTheme: const IconThemeData(color: PokeTheme.bezelGray),
      ),
      endDrawer: isWide
          ? Drawer(
              backgroundColor: PokeTheme.screenDark,
              child: ListView(
                children: [
                  const DrawerHeader(
                    decoration: BoxDecoration(color: PokeTheme.pokedexRed),
                    child: Center(
                      child: Icon(
                        Icons.catching_pokemon,
                        size: 80,
                        color: PokeTheme.bezelGray,
                      ),
                    ),
                  ),
                  for (int i = 0; i < _destinations.length; i++)
                    ListTile(
                      leading: Icon(
                        _destinations[i].$1,
                        color: _index == i
                            ? PokeTheme.sensorBlue
                            : PokeTheme.bezelGray,
                      ),
                      title: Text(
                        _destinations[i].$2,
                        style: TextStyle(
                          color: _index == i
                              ? PokeTheme.sensorBlue
                              : PokeTheme.bezelGray,
                        ),
                      ),
                      selected: _index == i,
                      onTap: () {
                        setState(() => _index = i);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            )
          : null,
      body: body,
      bottomNavigationBar: isWide
          ? null
          : BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              selectedItemColor: PokeTheme.sensorBlue,
              unselectedItemColor: PokeTheme.bezelGray.withOpacity(0.5),
              backgroundColor: PokeTheme.dPadBlack,
              items: [
                for (final d in _destinations)
                  BottomNavigationBarItem(icon: Icon(d.$1), label: d.$2),
              ],
            ),
    );
  }
}
