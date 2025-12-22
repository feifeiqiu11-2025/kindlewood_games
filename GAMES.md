# KindleWood Games - Development Guide

**Last Updated**: 2025-12-22

---

## Architecture Overview

KindleWood Games follows a **clean separation of concerns** between the games package and the main mobile app.

```
┌─────────────────────────────────────────────────────────────────┐
│                    KindleWoodKids (Mobile App)                   │
│  - Calls games via clean API                                     │
│  - Provides words from child's reading history                   │
│  - Handles game session tracking & limits                        │
│  - Manages user profiles & authentication                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ import 'package:kindlewood_games/...'
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 kindlewood_games (Flutter Package)               │
│  - Contains all game implementations                             │
│  - Self-contained game screens & logic                           │
│  - Shared models, audio, animations                              │
│  - No dependencies on main app                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Repository Locations

| Repository | Purpose | URL |
|------------|---------|-----|
| **kindlewood_games** | Games package (all games live here) | https://github.com/feifeiqiu11-2025/kindlewood_games |
| **KindleWoodKids** | Mobile app (consumes games package) | https://github.com/feifeiqiu11-2025/KindleWoodKids |

---

## Design Principles

### 1. Games Package is Self-Contained

The `kindlewood_games` package should:
- ✅ Have NO dependencies on KindleWoodKids app code
- ✅ Receive all data through constructor parameters (words, level, duration)
- ✅ Return results through callbacks (onGameEnd)
- ✅ Handle its own UI, animations, audio, and game logic
- ✅ Be usable by any Flutter app, not just KindleWoodKids

### 2. Clean API Contract

Each game screen should follow this pattern:

```dart
class NewGameScreen extends StatefulWidget {
  // INPUTS - What the game needs to run
  final List<String> words;           // Words to use in game
  final int level;                    // Difficulty (1-3)
  final Duration gameDuration;        // How long the game runs

  // OUTPUT - Callback when game ends
  final Function(int score, int correct, int total) onGameEnd;

  const NewGameScreen({
    super.key,
    required this.words,
    required this.level,
    this.gameDuration = const Duration(minutes: 1),
    required this.onGameEnd,
  });
}
```

### 3. Main App Responsibilities

The KindleWoodKids app should:
- Provide personalized words (from reading history or fallback list)
- Check and enforce game limits before launching
- Record game sessions to database after completion
- Handle navigation to/from game screens

```dart
// Example: How main app calls a game
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => WordRainScreen(
      words: await wordService.getWordsForLevel(profile, level),
      level: selectedLevel,
      gameDuration: const Duration(minutes: 1),
      onGameEnd: (score, correct, total) {
        debugPrint('Game ended: $score points');
      },
    ),
  ),
);

// Record session after game returns
if (result != null) {
  await gameService.recordGameSession(...);
}
```

---

## Package Structure

```
kindlewood_games/
├── lib/
│   ├── kindlewood_games.dart       # Public API - exports all games
│   │
│   ├── games/
│   │   ├── word_rain/              # Word Rain game
│   │   │   ├── word_rain_game.dart     # Game logic & state
│   │   │   ├── word_rain_screen.dart   # UI & animations
│   │   │   └── models/
│   │   │       └── falling_word.dart   # Word entity model
│   │   │
│   │   ├── new_game/               # Template for new games
│   │   │   ├── new_game_game.dart      # Game logic
│   │   │   ├── new_game_screen.dart    # Game UI
│   │   │   └── models/                 # Game-specific models
│   │   │
│   │   └── ... (future games)
│   │
│   ├── services/
│   │   └── game_service.dart       # Shared game utilities
│   │
│   └── shared/
│       ├── audio/
│       │   └── game_audio.dart     # Shared audio utilities
│       ├── models/
│       │   └── game_result.dart    # Shared result model
│       └── widgets/
│           └── countdown.dart      # Reusable widgets
│
├── pubspec.yaml
├── README.md
├── GAMES.md                        # This file
└── test/
```

---

## Adding a New Game

### Step 1: Create Game Folder

```bash
cd /Users/feifei/kindlewood_games
mkdir -p lib/games/new_game/models
```

### Step 2: Create Game Logic (`new_game_game.dart`)

```dart
/// New Game Logic
///
/// Core game mechanics and state management
class NewGameGame {
  final int level;
  final List<String> words;
  final Duration gameDuration;

  int score = 0;
  int wordsCorrect = 0;
  int wordsTotal = 0;

  NewGameGame({
    this.level = 1,
    required this.words,
    this.gameDuration = const Duration(minutes: 1),
  });

  // Level-based difficulty settings
  double get speed {
    switch (level) {
      case 1: return 1.0;   // Easy
      case 2: return 1.5;   // Medium
      case 3: return 2.0;   // Hard
      default: return 1.0;
    }
  }

  bool get showEmoji => level == 1;  // Hints on Level 1 only

  void recordCorrect() {
    wordsCorrect++;
    wordsTotal++;
    score += 10 * level;
  }

  void recordWrong() {
    wordsTotal++;
  }

  double get accuracy {
    if (wordsTotal == 0) return 0;
    return (wordsCorrect / wordsTotal) * 100;
  }
}
```

### Step 3: Create Game Screen (`new_game_screen.dart`)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'new_game_game.dart';

class NewGameScreen extends StatefulWidget {
  final List<String> words;
  final int level;
  final Duration gameDuration;
  final Function(int score, int correct, int total) onGameEnd;

  const NewGameScreen({
    super.key,
    required this.words,
    required this.level,
    this.gameDuration = const Duration(minutes: 1),
    required this.onGameEnd,
  });

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen>
    with TickerProviderStateMixin {

  // Game state
  late NewGameGame _game;
  late FlutterTts _tts;
  final AudioPlayer _correctSound = AudioPlayer();
  final AudioPlayer _wrongSound = AudioPlayer();

  bool _gameStarted = false;
  bool _gameEnded = false;
  int _timeRemaining = 60;
  int _treasuresCollected = 0;

  // Animation controller for game loop
  late AnimationController _gameLoopController;
  Timer? _gameTimer;

  @override
  void initState() {
    super.initState();
    _game = NewGameGame(
      level: widget.level,
      words: widget.words,
      gameDuration: widget.gameDuration,
    );
    _initAudio();
    _initGameLoop();
    _startIntroAndCountdown();
  }

  Future<void> _initAudio() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);

    try {
      await _correctSound.setUrl(
        'https://cdn.freesound.org/previews/320/320655_5260872-lq.mp3');
      await _wrongSound.setUrl(
        'https://cdn.freesound.org/previews/350/350985_5260872-lq.mp3');
    } catch (e) {
      debugPrint('Sound effects not loaded: $e');
    }
  }

  void _initGameLoop() {
    _gameLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
    )..addListener(_gameLoop);
  }

  Future<void> _startIntroAndCountdown() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _tts.speak('Get ready to play!');
    await Future.delayed(const Duration(seconds: 1));

    // Countdown: 3, 2, 1, Go!
    for (final num in ['3', '2', '1']) {
      if (!mounted) return;
      setState(() => /* update countdown UI */);
      await _tts.speak(num);
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (mounted) {
      setState(() {
        _gameStarted = true;
        _timeRemaining = widget.gameDuration.inSeconds;
      });
      _startGame();
    }
  }

  void _startGame() {
    _gameLoopController.repeat();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _gameStarted && !_gameEnded) {
        setState(() => _timeRemaining--);
        if (_timeRemaining <= 0) _endGame();
      }
    });
  }

  void _gameLoop() {
    if (!_gameStarted || _gameEnded) return;
    setState(() {
      // Update game state each frame
      // Move objects, check collisions, etc.
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _gameLoopController.stop();

    setState(() {
      _gameStarted = false;
      _gameEnded = true;
    });

    widget.onGameEnd(_treasuresCollected, _game.wordsCorrect, _game.wordsTotal);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _gameLoopController.dispose();
    _tts.stop();
    _correctSound.dispose();
    _wrongSound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_gameStarted && !_gameEnded) {
      return _buildIntroScreen();
    }
    if (_gameEnded) {
      return _buildEndScreen();
    }
    return _buildGameScreen();
  }

  Widget _buildIntroScreen() {
    // Countdown and instructions
  }

  Widget _buildGameScreen() {
    // Main game UI with:
    // - Top bar: Back button, treasure count, timer
    // - Game area: Game-specific content
    // - Bottom: Controls (if needed)
  }

  Widget _buildEndScreen() {
    // Results screen with:
    // - Celebration animation
    // - Treasures collected
    // - Stats (correct/total)
    // - Close button that pops with result data
  }
}
```

### Step 4: Export in Package API

Update `lib/kindlewood_games.dart`:

```dart
library kindlewood_games;

// Existing games
export 'games/word_rain/word_rain_game.dart';
export 'games/word_rain/word_rain_screen.dart';

// NEW GAME - Add exports here
export 'games/new_game/new_game_game.dart';
export 'games/new_game/new_game_screen.dart';

// Services
export 'services/game_service.dart';

// Shared
export 'shared/audio/game_audio.dart';
```

### Step 5: Commit to Games Repo

```bash
cd /Users/feifei/kindlewood_games
git add .
git commit -m "Add New Game: [description]"
git push origin main
```

### Step 6: Update Main App

In KindleWoodKids, update dependencies to get the new game:

```bash
cd /Users/feifei/KindleWoodKids
flutter pub upgrade kindlewood_games
```

Then add the game to `games_screen.dart` in the main app.

---

## Level Design Guidelines

All games should have 3 difficulty levels:

| Level | Difficulty | Visual Aids | Speed | Target Age |
|-------|------------|-------------|-------|------------|
| 1 | Easy | Emoji hints shown | Slowest | 3-5 years |
| 2 | Medium | No hints | Medium | 5-7 years |
| 3 | Hard | No hints + extra challenge | Fastest | 7+ years |

### Level 3 Special Mechanics (Optional)

- Bombs/obstacles to avoid
- Shield/power-ups that cost treasures
- Faster spawn rates
- More distractors

---

## Audio Guidelines

### Text-to-Speech (TTS)

```dart
await _tts.setLanguage('en-US');
await _tts.setSpeechRate(0.45);  // Slow for kids
await _tts.setVolume(1.0);
await _tts.setPitch(1.1);        // Slightly higher for friendly tone

// Try to use natural voice on iOS
try {
  await _tts.setVoice({'name': 'Samantha', 'locale': 'en-US'});
} catch (e) {
  // Fall back to default
}
```

### Sound Effects

Use freesound.org CDN for consistent sounds:

```dart
// Correct answer
await _correctSound.setUrl(
  'https://cdn.freesound.org/previews/320/320655_5260872-lq.mp3');

// Wrong answer
await _wrongSound.setUrl(
  'https://cdn.freesound.org/previews/350/350985_5260872-lq.mp3');

// Countdown beep
await _countdownSound.setUrl(
  'https://cdn.freesound.org/previews/254/254316_4597795-lq.mp3');
```

---

## Result Data Contract

Games should return consistent result data when popping:

```dart
Navigator.of(context).pop({
  'treasures': _treasuresCollected,     // Primary score
  'score': _treasuresCollected,         // Alias for compatibility
  'correct': _game.wordsCorrect,        // Correct answers
  'total': _game.wordsTotal,            // Total attempts
  'duration': widget.gameDuration.inSeconds - _timeRemaining,
});
```

---

## Shared Models

### FallingWord Model

Located in `games/word_rain/models/falling_word.dart`, this model is reused across games:

```dart
FallingWord(
  word: 'cat',
  emoji: FallingWord.getEmoji('cat'),  // Returns '🐱'
  x: 0.5,      // Horizontal position (0-1)
  y: -0.1,     // Vertical position (starts above screen)
  isTarget: true,
);
```

The `getEmoji()` method has 300+ word-to-emoji mappings for common vocabulary.

---

## Encouraging Messages

Games should use positive, encouraging feedback:

### Correct Answers
```dart
const correctMessages = [
  'Awesome! 🌟',
  'Great job! ⭐',
  'Super! 🎉',
  'Amazing! 💎',
  'Fantastic! 🏆',
  'Perfect! ✨',
  'Wonderful! 🎯',
];
```

### Wrong/Missed Answers
```dart
const missMessages = [
  'Nice try! 💪',
  'Keep going! 🌈',
  'You got this! 🚀',
  'Almost! Try again! 😊',
];
```

---

## Historical Note: Legacy Games

The following games were built directly in KindleWoodKids before this architecture was established:

- **Space Combat** (`lib/screens/games/space_combat_screen.dart`)
- **Word Puzzle** (`lib/screens/games/word_puzzle_screen.dart`)
- **Push & Match** (`lib/screens/games/push_match/`)

These remain in the main app for now. Future games should follow this guide and be added to the `kindlewood_games` package.

---

## Testing Checklist

Before releasing a new game:

- [ ] All 3 difficulty levels work correctly
- [ ] TTS pronounces words clearly
- [ ] Touch targets are appropriately sized for kids
- [ ] Sound effects play without errors
- [ ] Encouraging messages display correctly
- [ ] Game timer counts down accurately
- [ ] Final score calculation is correct
- [ ] Result data is returned correctly on exit
- [ ] Works on iPhone (various sizes)
- [ ] Works on iPad (portrait & landscape)
- [ ] Works on web (basic functionality)

---

## Quick Reference

### Create New Game
```bash
cd /Users/feifei/kindlewood_games
mkdir -p lib/games/my_new_game/models
# Create game files...
git add . && git commit -m "Add My New Game" && git push
```

### Update Main App
```bash
cd /Users/feifei/KindleWoodKids
flutter pub upgrade kindlewood_games
```

### Test Locally
```bash
# In kindlewood_games pubspec.yaml of KindleWoodKids, temporarily use:
kindlewood_games:
  path: ../kindlewood_games

# Test, then revert to Git dependency before committing:
kindlewood_games:
  git:
    url: https://github.com/feifeiqiu11-2025/kindlewood_games.git
    ref: main
```

---

## Contact

For questions about game development, refer to:
- This document (`GAMES.md`)
- `WORD_RAIN_SUMMARY.md` for detailed Word Rain implementation
- `README.md` for package overview
