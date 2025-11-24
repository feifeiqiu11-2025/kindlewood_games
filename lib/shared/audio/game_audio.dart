/// Game Audio Manager
///
/// Handles sound effects and background music for games.

class GameAudio {
  bool _isMuted = false;

  /// Mute/unmute all audio
  void setMuted(bool muted) {
    _isMuted = muted;
  }

  /// Play correct answer sound
  Future<void> playCorrect() async {
    if (_isMuted) return;
    // TODO: Play encouraging sound like "Hooray!", "Great job!"
  }

  /// Play wrong answer sound
  Future<void> playWrong() async {
    if (_isMuted) return;
    // TODO: Play gentle correction sound
  }

  /// Play word pronunciation
  Future<void> playWord(String word) async {
    if (_isMuted) return;
    // TODO: Use TTS to pronounce the word
  }

  /// Start background music
  Future<void> startBackgroundMusic() async {
    if (_isMuted) return;
    // TODO: Play mild background music
  }

  /// Stop background music
  Future<void> stopBackgroundMusic() async {
    // TODO: Stop background music
  }

  /// Play game complete celebration
  Future<void> playGameComplete() async {
    if (_isMuted) return;
    // TODO: Play celebration sound
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundMusic();
  }
}
