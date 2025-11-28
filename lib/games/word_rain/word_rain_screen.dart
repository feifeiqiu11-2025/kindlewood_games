import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'word_rain_game.dart';
import 'models/falling_word.dart';

/// Word Rain Game Screen
///
/// Main UI for the Word Rain game where words fall from the sky
/// and children tap the correct word they hear.

class WordRainScreen extends StatefulWidget {
  final List<String> words;
  final int level;
  final Duration gameDuration;
  final VoidCallback? onGameComplete;
  final Function(int score, int correct, int total)? onGameEnd;

  const WordRainScreen({
    super.key,
    required this.words,
    this.level = 1,
    this.gameDuration = const Duration(minutes: 2),
    this.onGameComplete,
    this.onGameEnd,
  });

  @override
  State<WordRainScreen> createState() => _WordRainScreenState();
}

class _WordRainScreenState extends State<WordRainScreen>
    with TickerProviderStateMixin {
  late WordRainGame _game;
  late FlutterTts _tts;

  // Audio players for sound effects
  final AudioPlayer _correctSound = AudioPlayer();
  final AudioPlayer _wrongSound = AudioPlayer();
  final AudioPlayer _countdownSound = AudioPlayer();
  final AudioPlayer _celebrationSound = AudioPlayer();
  Completer<void>? _ttsCompleter;

  // Game state
  List<FallingWord> _fallingWords = [];
  String _currentTargetWord = '';
  bool _isGameRunning = false;
  bool _isGameOver = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;
  int _treasuresCollected = 0;
  bool _isSpawning = false; // Prevent multiple spawns

  // Animation
  late AnimationController _fallController;
  Timer? _gameTimer;

  // Visual feedback
  bool _showCorrectFeedback = false;
  bool _showWrongFeedback = false;
  bool _showIntro = true;
  String _countdownText = '';
  String _encouragementText = '';

  // Encouraging messages for correct answers
  final List<String> _correctMessages = [
    'Awesome! 🌟',
    'Great job! ⭐',
    'Super! 🎉',
    'Amazing! 💎',
    'Fantastic! 🏆',
    'Perfect! ✨',
    'Wonderful! 🎯',
  ];

  // Encouraging messages for wrong/missed answers
  final List<String> _missMessages = [
    'Nice try! 💪',
    'Keep going! 🌈',
    'You got this! 🚀',
    'Almost! Try again! 😊',
  ];

  @override
  void initState() {
    super.initState();
    _game = WordRainGame(
      level: widget.level,
      words: widget.words,
      gameDuration: widget.gameDuration,
    );
    _remainingSeconds = widget.gameDuration.inSeconds;

    _tts = FlutterTts();
    _initTts();

    _fallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateFallingWords);

    _showIntroAndStart();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    // Set up completion handler for proper sync
    _tts.setCompletionHandler(() {
      _ttsCompleter?.complete();
    });

    // Initialize sound effects with public URLs
    try {
      // Success chime for correct answers
      await _correctSound.setUrl('https://cdn.freesound.org/previews/320/320655_5260872-lq.mp3');
      // Soft "oops" sound for wrong answers
      await _wrongSound.setUrl('https://cdn.freesound.org/previews/350/350985_5260872-lq.mp3');
      // Movie theater style countdown beep
      await _countdownSound.setUrl('https://cdn.freesound.org/previews/254/254316_4597795-lq.mp3');
    } catch (e) {
      // Sound files not found - will use TTS only
      debugPrint('Sound effects not loaded: $e');
    }
  }

  /// Speak text and wait for completion
  Future<void> _speakAndWait(String text) async {
    _ttsCompleter = Completer<void>();
    await _tts.speak(text);
    await _ttsCompleter!.future;
  }

  /// Play sound effect
  Future<void> _playSound(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      // Ignore sound errors
    }
  }

  Future<void> _showIntroAndStart() async {
    // Brief rules announcement first
    await Future.delayed(const Duration(milliseconds: 300));
    await _speakAndWait('Listen to the word, then tap the correct one to collect treasures!');
    await Future.delayed(const Duration(milliseconds: 300));

    // Exciting countdown
    if (!mounted) return;
    await _speakAndWait('Are you ready?');
    await Future.delayed(const Duration(milliseconds: 200));

    if (!mounted) return;
    setState(() => _countdownText = '3');
    _playSound(_countdownSound);
    await _speakAndWait('3');

    if (!mounted) return;
    setState(() => _countdownText = '2');
    _playSound(_countdownSound);
    await _speakAndWait('2');

    if (!mounted) return;
    setState(() => _countdownText = '1');
    _playSound(_countdownSound);
    await _speakAndWait('1');

    if (!mounted) return;
    setState(() => _countdownText = "Let's Go!");
    await _speakAndWait("Let's Go!");
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() => _showIntro = false);
      _startGame();
    }
  }

  void _startGame() {
    if (!mounted) return;
    setState(() {
      _isGameRunning = true;
      _isGameOver = false;
      _treasuresCollected = 0;
    });
    _fallController.repeat();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() => _remainingSeconds--);
        if (_remainingSeconds <= 0) _endGame();
      }
    });
    _spawnNewWords();
  }

  void _spawnNewWords() {
    if (!_isGameRunning || _isGameOver) return;
    _isSpawning = true;

    final random = Random();
    final targetWord = widget.words[random.nextInt(widget.words.length)];
    setState(() {
      _currentTargetWord = targetWord;
      _fallingWords = FallingWord.createSet(
        words: widget.words,
        count: _game.simultaneousWords,
        targetWord: targetWord,
      );
    });
    _tts.speak(targetWord);

    // Reset spawning flag after a short delay
    Future.delayed(const Duration(milliseconds: 100), () {
      _isSpawning = false;
    });
  }

  void _updateFallingWords() {
    if (!_isGameRunning || _isPaused || _isSpawning) return;
    bool allWordsFallen = false;

    setState(() {
      for (final word in _fallingWords) {
        if (!word.isTapped) {
          word.y += _game.fallSpeed / 10000;
        }
      }

      // Check if all words have fallen off screen or been tapped
      allWordsFallen = _fallingWords.isNotEmpty &&
          _fallingWords.every((w) => w.y > 1.1 || w.isTapped);
    });

    // Spawn new words when all are gone
    if (allWordsFallen && !_isSpawning) {
      _isSpawning = true; // Set flag immediately to prevent multiple triggers
      // Clear old words and spawn new ones
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _isGameRunning) {
          setState(() => _fallingWords = []);
          _spawnNewWords();
        }
      });
    }
  }

  void _onWordTapped(FallingWord word) {
    if (word.isTapped || !_isGameRunning) return;
    setState(() {
      word.isTapped = true;
      if (word.isTarget) {
        word.isCorrect = true;
        _game.recordCorrect();
        _treasuresCollected++;
        _playSound(_correctSound);
        _showEncouragingMessage(true);
        _showCorrectFeedbackBriefly();
        // Clear all words and spawn new set
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _isGameRunning) {
            setState(() => _fallingWords = []);
            _spawnNewWords();
          }
        });
      } else {
        word.isWrong = true;
        _game.recordWrong();
        _playSound(_wrongSound);
        _showEncouragingMessage(false);
        _showWrongFeedbackBriefly();
      }
    });
  }

  void _showEncouragingMessage(bool correct) {
    final random = Random();
    final messages = correct ? _correctMessages : _missMessages;
    setState(() {
      _encouragementText = messages[random.nextInt(messages.length)];
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _encouragementText = '');
    });
  }

  void _showCorrectFeedbackBriefly() {
    setState(() => _showCorrectFeedback = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showCorrectFeedback = false);
    });
  }

  void _showWrongFeedbackBriefly() {
    setState(() => _showWrongFeedback = true);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showWrongFeedback = false);
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    _fallController.stop();
    setState(() {
      _isGameRunning = false;
      _isGameOver = true;
    });
    // Play celebration sound
    _playCelebrationSound();
    widget.onGameEnd?.call(_game.score, _game.wordsCorrect, _game.wordsTotal);
  }

  Future<void> _playCelebrationSound() async {
    try {
      // Use kids celebration/achievement sound
      await _celebrationSound.setUrl('https://cdn.freesound.org/previews/320/320655_5260872-lq.mp3');
      await _celebrationSound.setVolume(0.7);
      await _celebrationSound.play();
    } catch (e) {
      debugPrint('Failed to play celebration sound: $e');
    }
  }

  void _repeatWord() {
    if (_currentTargetWord.isNotEmpty) _tts.speak(_currentTargetWord);
  }

  void _togglePause() => setState(() => _isPaused = !_isPaused);

  @override
  void dispose() {
    _gameTimer?.cancel();
    _fallController.dispose();
    _tts.stop();
    _correctSound.dispose();
    _wrongSound.dispose();
    _countdownSound.dispose();
    _celebrationSound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Return game results when user presses back button
        Navigator.of(context).pop({
          'treasures': _treasuresCollected,
          'score': _treasuresCollected,
          'correct': _game.wordsCorrect,
          'total': _game.wordsTotal,
          'duration': widget.gameDuration.inSeconds - _remainingSeconds,
        });
        return false; // We handle the pop ourselves
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.lightBlue.shade200, Colors.lightBlue.shade50, Colors.green.shade100],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                ..._buildClouds(),
                _buildGameArea(),
                _buildTopBar(),
                _buildRepeatButton(),
                if (_encouragementText.isNotEmpty) _buildEncouragementOverlay(),
                if (_showCorrectFeedback) _buildCorrectFeedback(),
                if (_showWrongFeedback) _buildWrongFeedback(),
                if (_isGameOver) _buildGameOverOverlay(),
                if (_isPaused) _buildPauseOverlay(),
                if (_showIntro) _buildIntroOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildClouds() => [
    Positioned(top: 20, left: 20, child: Icon(Icons.cloud, size: 60, color: Colors.white.withOpacity(0.7))),
    Positioned(top: 40, right: 40, child: Icon(Icons.cloud, size: 80, color: Colors.white.withOpacity(0.8))),
    Positioned(top: 80, left: 100, child: Icon(Icons.cloud, size: 50, color: Colors.white.withOpacity(0.6))),
  ];

  Widget _buildTopBar() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // Return game results when user taps back button
                Navigator.of(context).pop({
                  'treasures': _treasuresCollected,
                  'score': _treasuresCollected,
                  'correct': _game.wordsCorrect,
                  'total': _game.wordsTotal,
                  'duration': widget.gameDuration.inSeconds - _remainingSeconds,
                });
              },
            ),
            // Treasure count instead of score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Text('💎', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text('$_treasuresCollected', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _remainingSeconds <= 30 ? Colors.red.shade100 : Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                Icon(Icons.timer, color: _remainingSeconds <= 30 ? Colors.red : Colors.blue, size: 20),
                const SizedBox(width: 4),
                Text(timeString, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _remainingSeconds <= 30 ? Colors.red : Colors.black)),
              ]),
            ),
            IconButton(icon: const Icon(Icons.pause, color: Colors.white), onPressed: _togglePause),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatButton() => Positioned(
    bottom: 20, left: 0, right: 0,
    child: Center(
      child: ElevatedButton.icon(
        onPressed: _repeatWord,
        icon: const Icon(Icons.volume_up),
        label: const Text('Hear Again'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
      ),
    ),
  );

  Widget _buildGameArea() => Positioned.fill(
    top: 60, bottom: 80,
    child: LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: _fallingWords.map((word) => Positioned(
          left: word.x * constraints.maxWidth - 50,
          top: word.y * constraints.maxHeight,
          child: GestureDetector(
            onTap: () => _onWordTapped(word),
            child: _buildWordCloud(word),
          ),
        )).toList(),
      );
    }),
  );

  Widget _buildWordCloud(FallingWord word) {
    final Color bgColor = word.isCorrect
        ? Colors.green.shade400
        : word.isWrong
            ? Colors.red.shade400
            : Colors.white;
    final Color textColor = word.isCorrect || word.isWrong
        ? Colors.white
        : Colors.purple.shade700;

    // Show emoji based on game level
    final bool showEmoji = _game.showEmoji;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: bgColor.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
              border: Border.all(
                color: word.isCorrect
                    ? Colors.green.shade600
                    : word.isWrong
                        ? Colors.red.shade600
                        : Colors.blue.shade200,
                width: 3,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showEmoji) ...[
                  Text(
                    word.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  word.word,
                  style: TextStyle(
                    fontSize: showEmoji ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          // Show +1 treasure when correct
          if (word.isCorrect)
            Positioned(
              top: -10,
              right: -10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Text('+1 💎', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEncouragementOverlay() => Positioned(
    top: 70,
    left: 0,
    right: 0,
    child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          _encouragementText,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _encouragementText.contains('try') || _encouragementText.contains('Almost')
                ? Colors.orange.shade700
                : Colors.green.shade700,
          ),
        ),
      ),
    ),
  );

  Widget _buildCorrectFeedback() => Positioned(
    top: 60,
    left: 20,
    right: 20,
    child: Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildWrongFeedback() => Positioned(
    top: 60,
    left: 20,
    right: 20,
    child: Container(
      height: 4,
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildPauseOverlay() => Positioned.fill(
    child: Container(
      color: Colors.black54,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.pause_circle, size: 80, color: Colors.white),
          const SizedBox(height: 16),
          const Text('Paused', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _togglePause,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            child: const Text('Resume', style: TextStyle(fontSize: 18)),
          ),
        ]),
      ),
    ),
  );

  Widget _buildGameOverOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Stack(
          children: [
            // Confetti emojis scattered around
            ..._buildConfettiEmojis(),
            Center(
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Fireworks-style pop-up animation for party emoji
                  SizedBox(
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Sparkle particles shooting outward
                        ...List.generate(8, (i) {
                          final angle = (i * 45) * 3.14159 / 180;
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 600 + (i * 50)),
                            curve: Curves.easeOut,
                            builder: (context, value, child) => Transform.translate(
                              offset: Offset(
                                30 * value * (i.isEven ? 1 : -1) * (i % 3 == 0 ? 0.5 : 1),
                                -30 * value * (i < 4 ? 1 : -0.5),
                              ),
                              child: Opacity(
                                opacity: (1 - value * 0.5).clamp(0.0, 1.0),
                                child: Text(
                                  i % 2 == 0 ? '✨' : '⭐',
                                  style: TextStyle(fontSize: 16 + (i * 2).toDouble()),
                                ),
                              ),
                            ),
                          );
                        }),
                        // Main party emoji with pop effect
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            child: const Text('🎉', style: TextStyle(fontSize: 60)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Great Job!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              // Treasure collected
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade300, width: 2),
                ),
                child: Column(
                  children: [
                    const Text('Treasures Collected', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 36)),
                        const SizedBox(width: 8),
                        Text(
                          '$_treasuresCollected',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_game.wordsCorrect} out of ${_game.wordsTotal} correct',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop({
                    'treasures': _treasuresCollected,
                    'score': _treasuresCollected,
                    'correct': _game.wordsCorrect,
                    'total': _game.wordsTotal,
                    'duration': widget.gameDuration.inSeconds - _remainingSeconds,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              ]),
            ),
          ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfettiEmojis() {
    final confettiEmojis = ['🎊', '🎉', '⭐', '✨', '💎', '🌟', '🏆', '🎈'];
    final random = Random();
    return List.generate(12, (index) {
      final emoji = confettiEmojis[random.nextInt(confettiEmojis.length)];
      final left = random.nextDouble() * 300;
      final top = random.nextDouble() * 600;
      return Positioned(
        left: left,
        top: top,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 500 + random.nextInt(500)),
          builder: (context, opacity, child) => Opacity(
            opacity: opacity,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
      );
    });
  }

  Widget _buildIntroOverlay() => Positioned.fill(
    child: Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_countdownText.isEmpty) ...[
                const Text('🎯', style: TextStyle(fontSize: 50)),
                const SizedBox(height: 16),
                const Text(
                  'Get Ready!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Listen & tap the word!',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ] else ...[
                Text(
                  _countdownText,
                  style: TextStyle(
                    fontSize: _countdownText.length > 1 ? 40 : 80,
                    fontWeight: FontWeight.bold,
                    color: _countdownText == "Let's Go!" ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
