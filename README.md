# KindleWood Games

Educational mini-games Flutter package for KindleWood Kids app.

## Features

- **Word Rain** - Words fall from the sky, children tap the word they hear
- Sound effects and background music
- Game session tracking
- Time management with daily limits

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  kindlewood_games:
    git:
      url: https://github.com/feifeiqiu11-2025/kindlewood_games.git
```

## Usage

```dart
import 'package:kindlewood_games/kindlewood_games.dart';

// Launch Word Rain game
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => WordRainScreen(
      words: ['cat', 'dog', 'bird'],
      level: 1,
      onGameComplete: () {
        // Handle game completion
      },
    ),
  ),
);
```

## Games

### Word Rain
- 3-5 words fall from the sky simultaneously
- System reads one word aloud
- Child taps the correct falling word
- 2-minute games with 3 difficulty levels

## Development

```bash
# Get dependencies
flutter pub get

# Run tests
flutter test
```

## License

MIT
