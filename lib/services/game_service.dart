/// Game Service
///
/// Handles game session tracking, time management, and word data fetching.

class GameService {
  /// Check if child has remaining game time for today
  Future<bool> hasRemainingTime({
    required String childProfileId,
    required int dailyLimitMinutes,
  }) async {
    // TODO: Query game_sessions for today's total duration
    // Compare with dailyLimitMinutes
    return true;
  }

  /// Get remaining game time in seconds
  Future<int> getRemainingTimeSeconds({
    required String childProfileId,
    required int dailyLimitMinutes,
  }) async {
    // TODO: Calculate remaining time
    return dailyLimitMinutes * 60;
  }

  /// Start a new game session
  Future<String> startSession({
    required String childProfileId,
    required String gameType,
  }) async {
    // TODO: Insert into game_sessions table
    return 'session-id';
  }

  /// End a game session
  Future<void> endSession({
    required String sessionId,
    required int durationSeconds,
    required int score,
    required int levelReached,
    required int wordsCorrect,
    required int wordsTotal,
    String? wordSource,
  }) async {
    // TODO: Update game_sessions with results
  }

  /// Get words for the game based on priority
  Future<List<String>> getGameWords({
    required String childProfileId,
    int count = 20,
  }) async {
    // Priority:
    // 1. Words child tapped during story reading
    // 2. Random words from recently read stories
    // 3. Age-appropriate fallback vocabulary

    // TODO: Implement word fetching logic
    return [
      'cat', 'dog', 'bird', 'fish', 'tree',
      'sun', 'moon', 'star', 'cloud', 'rain',
      'red', 'blue', 'green', 'yellow', 'orange',
      'one', 'two', 'three', 'four', 'five',
    ];
  }
}
