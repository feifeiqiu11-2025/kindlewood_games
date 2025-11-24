import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  // Game state
  List<FallingWord> _fallingWords = [];
  String _currentTargetWord = '';
  bool _isGameRunning = false;
  bool _isGameOver = false;
  bool _isPaused = false;
  int _remainingSeconds = 0;

  // Animation
  late AnimationController _fallController;
  Timer? _gameTimer;

  // Visual feedback
  bool _showCorrectFeedback = false;
  bool _showWrongFeedback = false;

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

    Future.delayed(const Duration(milliseconds: 500), _startGame);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  void _startGame() {
    if (!mounted) return;
    setState(() {
      _isGameRunning = true;
      _isGameOver = false;
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
  }

  void _updateFallingWords() {
    if (!_isGameRunning || _isPaused) return;
    bool needsRespawn = false;
    setState(() {
      for (final word in _fallingWords) {
        if (!word.isTapped) {
          word.y += _game.fallSpeed / 10000;
          if (word.y > 1.1) {
            if (word.isTarget && !word.isTapped) {
              _game.recordWrong();
              _showWrongFeedbackBriefly();
            }
            needsRespawn = true;
          }
        }
      }
    });
    if (needsRespawn) {
      Future.delayed(const Duration(milliseconds: 500), _spawnNewWords);
    }
  }

  void _onWordTapped(FallingWord word) {
    if (word.isTapped || !_isGameRunning) return;
    setState(() {
      word.isTapped = true;
      if (word.isTarget) {
        word.isCorrect = true;
        _game.recordCorrect();
        _showCorrectFeedbackBriefly();
        Future.delayed(const Duration(milliseconds: 800), _spawnNewWords);
      } else {
        word.isWrong = true;
        _game.recordWrong();
        _showWrongFeedbackBriefly();
      }
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
    widget.onGameEnd?.call(_game.score, _game.wordsCorrect, _game.wordsTotal);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              if (_showCorrectFeedback) _buildCorrectFeedback(),
              if (_showWrongFeedback) _buildWrongFeedback(),
              if (_isGameOver) _buildGameOverOverlay(),
              if (_isPaused) _buildPauseOverlay(),
            ],
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
            IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text('${_game.score}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          left: word.x * constraints.maxWidth - 40,
          top: word.y * constraints.maxHeight,
          child: GestureDetector(
            onTap: () => _onWordTapped(word),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: word.isCorrect ? Colors.green : word.isWrong ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Text(
                word.word,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: word.isCorrect || word.isWrong ? Colors.white : Colors.blue.shade800),
              ),
            ),
          ),
        )).toList(),
      );
    }),
  );

  Widget _buildCorrectFeedback() => Positioned.fill(
    child: Container(color: Colors.green.withOpacity(0.3), child: const Center(child: Icon(Icons.check_circle, size: 100, color: Colors.green))),
  );

  Widget _buildWrongFeedback() => Positioned.fill(
    child: Container(color: Colors.red.withOpacity(0.2), child: const Center(child: Icon(Icons.close, size: 100, color: Colors.red))),
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
    final accuracy = _game.accuracy.toStringAsFixed(0);
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('Great Job!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildStatRow('Score', '${_game.score}', Icons.star),
              _buildStatRow('Correct', '${_game.wordsCorrect}/${_game.wordsTotal}', Icons.check_circle),
              _buildStatRow('Accuracy', '$accuracy%', Icons.percent),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(
                  onPressed: () { Navigator.of(context).pop(); widget.onGameComplete?.call(); },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Exit'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _game = WordRainGame(level: widget.level, words: widget.words, gameDuration: widget.gameDuration);
                    _remainingSeconds = widget.gameDuration.inSeconds;
                    setState(() { _isGameOver = false; _fallingWords = []; });
                    _startGame();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Play Again'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 24, color: Colors.blue),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontSize: 16)),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ]),
  );
}
