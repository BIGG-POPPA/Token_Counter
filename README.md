# 🎮 Token Game: Live Event Console

**A real-time, Pokédex-themed game-master console for running token-based elimination tournaments. Built with Flutter + Firebase, shipped in a weekend.**

---

## 💡 What It Is

Running a live token-based game at an event usually means clipboards, spreadsheets and arguments about who has how many tokens. **Token Game replaces all of that with one app.** Organizers register players, start rounds, award winners and watch the leaderboard update live on every connected device.

**The game loop:**
- Every player registers with a 5-digit ID and starts with **2 tokens**.
- Starting a game costs **1 token** per participant.
- Winners earn **+1 win, +1 band (max 2) and +1 token (capped at 2)**.
- At **0 tokens a player is eliminated**.

---

## ✨ Key Features

- **Three game modes:**
  - **1v1:** head-to-head duels.
  - **Team Royale:** dynamic teams (A, B, C…) with per-team elimination until one team remains.
  - **Free-For-All:** any number of players, with a game-over award for the remaining survivors.
- **Atomic game economy:** token deduction, play counts and rewards run as **Firebase transactions**, so two organizers on two devices can't corrupt a player's balance.
- **Undo and cancel safety net:** pre-game snapshots let organizers roll a round back, or undo a mistaken award, in one tap.
- **Live leaderboard:** real-time sync via Realtime Database streams, ranked by wins → bands → tokens, with instant search by name or ID.
- **Player profiles:** full stats (played, won, lost) plus a timestamped win and manual-token history.
- **Admin controls:** PIN-gated player deletion, manual token grants, and a full database wipe. Deleted players are archived to a history log rather than lost.
- **Responsive layout:** bottom navigation on mobile, side drawer on wide screens, one codebase.
- **Distinct visual identity:** glassmorphism cards, a Pokédex-inspired palette, and Rubik Bubbles typography.

---

## 🛠 Tech Stack

| Layer | Choice |
|---|---|
| **Framework** | Flutter (Material 3) |
| **Language** | Dart |
| **Backend** | Firebase Realtime Database (live streams and transactions) |
| **State management** | `provider` (`ChangeNotifier`) |
| **UI** | Custom `GlassCard` (BackdropFilter blur), `google_fonts` |

---

## 🏗 Architecture & Development Context

> **TL;DR:** This is a **weekend MVP**, built to be used at a live event, not to be a reference architecture. The goal was maximum product velocity with a working, good-looking, complete feature set. The architecture reflects that choice on purpose.

### The brief I gave myself

Ship a fully functional, cross-platform event tool fast: registration, three game modes, live leaderboard, admin controls, and a distinct visual identity. A tool like this has a hard deadline (the event), so **feature completeness and reliability of the core loop beat architectural purity.**

### Deliberate MVP trade-offs

| Decision | Why I made it (MVP) | What I'd do at scale |
|---|---|---|
| **Screens call `FirebaseService` directly via Provider** instead of repository, use-case and domain layers | Fewest moving parts, fastest path to a working loop | Introduce a repository interface and use-cases so the UI never touches the backend |
| **Game-session state lives in the console screen's `setState`** (teams, snapshots, backups) | Quick to iterate on three different game modes in one place | Extract a `GameSessionController`, one per mode, with unit tests |
| **Admin PINs are checked client-side** | Lightweight friction against accidental taps at a supervised, in-person event | Firebase Auth with custom claims plus locked-down Security Rules |
| **No automated test suite** | Manual playtesting against real game flows was the faster feedback loop | Unit tests for the token and reward rules, widget tests for each mode |
| **Two overlapping state classes** (`AppState`, `LeaderboardProvider`) from fast iteration | Let me try a leaderboard approach without breaking the working one | Consolidate into a single source of truth |
| **Firebase config committed in-repo** | Standard FlutterFire CLI output, zero setup friction | Environment-based config plus restricted keys and App Check |

### What *is* solid

The parts where correctness matters were built carefully rather than quickly:

- **Token and reward logic runs inside Firebase transactions.** Concurrent writes can't double-spend or corrupt balances.
- **Reward caps are enforced server-side in the transaction** (max 2 bands, max 2 tokens), not just in the UI.
- **Every destructive action has a recovery path:** confirm dialogs, a PIN gate, snapshot-based undo and cancel, and an archive instead of a hard delete.
- **Input validation at the edges:** 5-digit IDs only, duplicate-registration checks, and duplicate or eliminated-player checks in every game mode.

### Productionization roadmap

If this moved from event tool to product, the order of work would be:

1. Move admin actions to authenticated roles with Security Rules.
2. Extract game logic into a testable domain layer, with the token and reward rules first.
3. Replace direct service calls with a repository abstraction.
4. Consolidate state into one provider tree.
5. Add CI with unit and widget tests.

---

## 🚀 Getting Started

```bash
# 1. Clone
git clone https://github.com/<your-username>/token_game.git
cd token_game

# 2. Install dependencies
flutter pub get

# 3. Connect your own Firebase project
dart pub global activate flutterfire_cli
flutterfire configure

# 4. Run
flutter run
```

**Requirements:** Flutter SDK 3.x, a Firebase project with **Realtime Database** enabled.

---

## 📁 Project Structure

```
lib/
├── main.dart                  # App shell, theming, responsive navigation
├── firebase_options.dart      # FlutterFire-generated config
├── firebase_service.dart      # Realtime DB access and atomic game transactions
├── app_state.dart             # Live participant and history state
├── participant.dart           # Data model
├── registration_screen.dart   # Player sign-up
├── console_screen.dart        # 1v1 / Team Royale / FFA game engine UI
├── leaderboard_screen.dart    # Rankings, search, player profiles, admin actions
├── history_screen.dart        # Archived players and DB wipe
├── glass_card.dart            # Reusable glassmorphism widget
└── theme.dart                 # Pokédex color palette
```

---

## 📚 What I Learned

- Using **Firebase transactions** to keep shared game state (tokens, bands, wins) consistent when several devices write at once
- Designing **undo and cancel flows** by snapshotting state before a destructive or irreversible action
- Streaming **real-time data** from Realtime Database into the UI with `provider` and `ChangeNotifier`
- Managing multi-mode game flows (1v1, teams, free-for-all) with validation at every input step
- Building a **responsive, reusable UI layer** (glassmorphism components, adaptive navigation) in a single Flutter codebase
- Making deliberate **speed vs. scalability trade-offs**, and knowing exactly what I'd refactor first

---

## 👤 Author

**Your Name**, 2nd-year B.Tech CSE (Batch of 2029)

[GitHub](https://github.com/<your-username>) · [LinkedIn](https://www.linkedin.com/in/sohan-dodamani/) · [Email](mailto:<sohandodamani@gmail.com>)

---

<sub>Built fast, shipped working, and documented honestly.</sub>
