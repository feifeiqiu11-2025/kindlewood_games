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

  /// Get fall speed based on level (much slower for kids)
  double get fallSpeed {
    switch (level) {
      case 1:
        return 15.0; // Very slow for little kids
      case 2:
        return 25.0; // Slow
      case 3:
        return 35.0; // Medium
      default:
        return 15.0;
    }
  }

  /// Get number of words falling simultaneously
  /// All levels: 3 words
  int get simultaneousWords => 3;

  /// Show emoji with words
  /// Level 1: with emoji
  /// Level 2 & 3: without emoji
  bool get showEmoji => level == 1;

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
