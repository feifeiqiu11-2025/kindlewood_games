/// Word Rain Game Logic
///
/// Core game mechanics for the Word Rain game where words fall from the sky
/// and children tap the word they hear.

class WordRainGame {
  final int level;
  final List<String> words;
  final Duration gameDuration;

  int score = 0;
  int wordsCorrect = 0;
  int wordsTotal = 0;

  WordRainGame({
    this.level = 1,
    required this.words,
    this.gameDuration = const Duration(minutes: 2),
  });

  /// Get fall speed based on level
  double get fallSpeed {
    switch (level) {
      case 1:
        return 50.0; // Slow
      case 2:
        return 75.0; // Medium
      case 3:
        return 100.0; // Fast
      default:
        return 50.0;
    }
  }

  /// Get number of words falling simultaneously
  int get simultaneousWords {
    switch (level) {
      case 1:
        return 3;
      case 2:
        return 4;
      case 3:
        return 5;
      default:
        return 3;
    }
  }

  /// Record a correct answer
  void recordCorrect() {
    wordsCorrect++;
    wordsTotal++;
    score += 10 * level;
  }

  /// Record a wrong answer
  void recordWrong() {
    wordsTotal++;
  }

  /// Get accuracy percentage
  double get accuracy {
    if (wordsTotal == 0) return 0;
    return (wordsCorrect / wordsTotal) * 100;
  }
}
