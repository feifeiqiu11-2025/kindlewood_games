import 'dart:math';

/// Model for a falling word in the Word Rain game
class FallingWord {
  final String word;
  final String emoji;
  final double x; // Horizontal position (0.0 to 1.0)
  double y; // Vertical position (0.0 = top, 1.0 = bottom)
  final bool isTarget; // Is this the word to tap?
  bool isTapped = false;
  bool isCorrect = false;
  bool isWrong = false;

  FallingWord({
    required this.word,
    required this.emoji,
    required this.x,
    this.y = -0.1, // Start above the screen
    this.isTarget = false,
  });

  /// Get emoji for a word
  static String getEmoji(String word) {
    const wordEmojis = {
      'cat': '🐱', 'dog': '🐕', 'bird': '🐦', 'fish': '🐟', 'tree': '🌳',
      'sun': '☀️', 'moon': '🌙', 'star': '⭐', 'cloud': '☁️', 'rain': '🌧️',
      'red': '🔴', 'blue': '🔵', 'green': '🟢', 'yellow': '🟡', 'orange': '🟠',
      'one': '1️⃣', 'two': '2️⃣', 'three': '3️⃣', 'four': '4️⃣', 'five': '5️⃣',
      'happy': '😊', 'sad': '😢', 'big': '🐘', 'small': '🐜', 'fast': '🏃',
      'apple': '🍎', 'banana': '🍌', 'car': '🚗', 'house': '🏠', 'book': '📚',
      'ball': '⚽', 'flower': '🌸', 'heart': '❤️', 'water': '💧', 'fire': '🔥',
    };
    return wordEmojis[word.toLowerCase()] ?? '📝';
  }

  /// Create a set of falling words with one target
  static List<FallingWord> createSet({
    required List<String> words,
    required int count,
    required String targetWord,
  }) {
    final random = Random();
    final result = <FallingWord>[];

    // Shuffle and pick words
    final shuffled = List<String>.from(words)..shuffle(random);
    final selectedWords = <String>[];

    // Ensure target is included
    selectedWords.add(targetWord);

    // Add other unique words
    for (final word in shuffled) {
      if (selectedWords.length >= count) break;
      if (word != targetWord) {
        selectedWords.add(word);
      }
    }

    // Shuffle the selected words
    selectedWords.shuffle(random);

    // Create falling words with evenly distributed x positions
    for (int i = 0; i < selectedWords.length; i++) {
      final word = selectedWords[i];
      // Distribute horizontally with some padding
      final x = (i + 0.5) / selectedWords.length;

      result.add(FallingWord(
        word: word,
        emoji: getEmoji(word),
        x: x,
        y: -0.05 - (random.nextDouble() * 0.1), // Slight vertical offset
        isTarget: word == targetWord,
      ));
    }

    return result;
  }
}
