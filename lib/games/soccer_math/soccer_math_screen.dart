import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'soccer_math_game.dart';
import 'models/field_player.dart';
import 'models/game_route.dart';

/// Soccer Math Game Screen
/// A soccer-themed learning game where kids pass to numbered players
class SoccerMathScreen extends StatefulWidget {
  final int level;
  final Duration gameDuration;
  final Function(int score, int correct, int total) onGameEnd;

  const SoccerMathScreen({
    super.key,
    required this.level,
    this.gameDuration = const Duration(minutes: 2),
    required this.onGameEnd,
  });

  @override
  State<SoccerMathScreen> createState() => _SoccerMathScreenState();
}

class _SoccerMathScreenState extends State<SoccerMathScreen>
    with TickerProviderStateMixin {
  // Game logic
  late SoccerMathGame _game;

  // Audio
  late FlutterTts _tts;
  Completer<void>? _ttsCompleter;
  final AudioPlayer _kickSound = AudioPlayer();
  final AudioPlayer _goalSound = AudioPlayer();
  final AudioPlayer _wrongSound = AudioPlayer();
  final AudioPlayer _countdownSound = AudioPlayer();

  // Game state
  GameState _gameState = GameState.intro;
  String _countdownText = '';
  int _timeRemaining = 120;
  Timer? _gameTimer;

  // Aiming state
  double _aimAngle = 0.0;
  bool _isDragging = false;

  // Animation state
  bool _ballMoving = false;
  Offset? _ballTargetPosition;
  late AnimationController _ballAnimController;
  late Animation<Offset> _ballAnimation;

  // Feedback state
  String? _feedbackMessage;
  bool _showFeedback = false;
  int? _highlightedPlayerId;

  // Player image loading
  bool _playerImageLoaded = false;

  @override
  void initState() {
    super.initState();
    _game = SoccerMathGame(
      level: widget.level,
      gameDuration: widget.gameDuration,
      playerCount: 8,
    );
    _game.initializeField();

    _tts = FlutterTts();
    _initAudio();
    _initAnimations();
    _preloadPlayerImage();

    // Start intro sequence
    _startIntroSequence();
  }

  Future<void> _preloadPlayerImage() async {
    // Try to preload the player image
    try {
      await precacheImage(
        const AssetImage('assets/images/soccer_math/player_yellow.png',
            package: 'kindlewood_games'),
        context,
      );
      if (mounted) {
        setState(() => _playerImageLoaded = true);
      }
    } catch (e) {
      debugPrint('Could not load player image: $e');
      // Will use emoji fallback
    }
  }

  Future<void> _initAudio() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.1);

    try {
      await _tts.setVoice({'name': 'Samantha', 'locale': 'en-US'});
    } catch (e) {
      debugPrint('Could not set preferred voice: $e');
    }

    _tts.setCompletionHandler(() {
      _ttsCompleter?.complete();
    });

    try {
      await _kickSound.setUrl(
          'https://cdn.freesound.org/previews/156/156031_2703579-lq.mp3');
      await _kickSound.setVolume(0.4);
      await _goalSound.setUrl(
          'https://cdn.freesound.org/previews/320/320655_5260872-lq.mp3');
      await _wrongSound.setUrl(
          'https://cdn.freesound.org/previews/350/350985_5260872-lq.mp3');
      await _countdownSound.setUrl(
          'https://cdn.freesound.org/previews/254/254316_4597795-lq.mp3');
    } catch (e) {
      debugPrint('Sound effects not loaded: $e');
    }
  }

  void _initAnimations() {
    _ballAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _ballAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _ballMoving = false;
          _ballTargetPosition = null;
        });
      }
    });
  }

  Future<void> _speakAndWait(String text) async {
    _ttsCompleter = Completer<void>();
    await _tts.speak(text);
    await _ttsCompleter!.future;
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _playSound(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      // Ignore sound errors
    }
  }

  Future<void> _startIntroSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _speakAndWait('Follow the route to score!');
    await Future.delayed(const Duration(milliseconds: 300));

    // Countdown
    for (final num in ['3', '2', '1']) {
      if (!mounted) return;
      setState(() => _countdownText = num);
      _playSound(_countdownSound);
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted) return;
    setState(() => _countdownText = "Go!");
    await _speakAndWait("Go!");
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _gameState = GameState.playing;
        _timeRemaining = widget.gameDuration.inSeconds;
      });
      _startGameTimer();
      _announceCurrentTarget();
    }
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _gameState == GameState.playing) {
        setState(() => _timeRemaining--);
        if (_timeRemaining <= 0) {
          _endGame();
        }
      }
    });
  }

  void _announceCurrentTarget() {
    final target = _game.currentRoute?.currentTargetNumber;
    if (target != null) {
      _speak('Pass to $target!');
    } else if (_game.currentRoute?.isReadyForGoal == true) {
      _speak('Shoot to goal!');
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (_gameState != GameState.playing || _ballMoving) return;
    setState(() => _isDragging = true);
  }

  void _handlePanUpdate(DragUpdateDetails details, Size fieldSize) {
    if (!_isDragging || _ballMoving) return;

    // Calculate angle from ball position to drag position
    final ballScreenPos = Offset(
      _game.ball.position.dx * fieldSize.width,
      _game.ball.position.dy * fieldSize.height,
    );

    final dragPos = details.localPosition;
    final dx = dragPos.dx - ballScreenPos.dx;
    final dy = dragPos.dy - ballScreenPos.dy;

    setState(() {
      _aimAngle = atan2(dy, dx);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDragging || _ballMoving) return;
    setState(() => _isDragging = false);
  }

  void _handleTap() {
    if (_gameState != GameState.playing || _ballMoving) return;

    // Process the kick
    _playSound(_kickSound);
    final result = _game.processKick(_aimAngle);

    // Show feedback
    setState(() {
      _feedbackMessage = result.message;
      _showFeedback = true;
    });

    // Handle result
    switch (result.type) {
      case KickResultType.correctPass:
      case KickResultType.goalScored:
        _animateBallTo(result.targetPosition!);
        if (result.type == KickResultType.goalScored) {
          _playSound(_goalSound);
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _announceCurrentTarget();
            }
          });
        } else {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              _announceCurrentTarget();
            }
          });
        }
        break;

      case KickResultType.wrongTarget:
      case KickResultType.missedAll:
        _playSound(_wrongSound);
        break;
    }

    // Hide feedback after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showFeedback = false);
      }
    });
  }

  void _animateBallTo(Offset target) {
    setState(() {
      _ballMoving = true;
      _ballTargetPosition = target;
    });

    _ballAnimation = Tween<Offset>(
      begin: _game.ball.position,
      end: target,
    ).animate(CurvedAnimation(
      parent: _ballAnimController,
      curve: Curves.easeOut,
    ));

    _ballAnimController.forward(from: 0);
  }

  void _showHint() {
    // Find the current target player and highlight them
    final targetNumber = _game.currentRoute?.currentTargetNumber;
    if (targetNumber == null) return;

    final targetPlayer = _game.players.firstWhere(
      (p) => p.jerseyNumber == targetNumber,
      orElse: () => _game.players.first,
    );

    setState(() {
      _highlightedPlayerId = targetPlayer.id;
    });

    // Remove highlight after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _highlightedPlayerId = null);
      }
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    setState(() => _gameState = GameState.ended);
    widget.onGameEnd(_game.treasures, _game.correctPasses, _game.totalAttempts);
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _ballAnimController.dispose();
    _tts.stop();
    _kickSound.dispose();
    _goalSound.dispose();
    _wrongSound.dispose();
    _countdownSound.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_gameState) {
      case GameState.intro:
        return _buildIntroScreen();
      case GameState.playing:
        return _buildGameScreen();
      case GameState.ended:
        return _buildEndScreen();
    }
  }

  Widget _buildIntroScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade400,
              Colors.green.shade600,
            ],
          ),
        ),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_countdownText.isEmpty) ...[
                  const Text('⚽', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text(
                    'Pass & Count',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow the route to score!',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ] else ...[
                  Text(
                    _countdownText,
                    style: TextStyle(
                      fontSize: _countdownText.length > 1 ? 48 : 80,
                      fontWeight: FontWeight.bold,
                      color: _countdownText == "Go!"
                          ? Colors.green
                          : Colors.orange,
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

  Widget _buildGameScreen() {
    return Scaffold(
      body: Container(
        color: Colors.green.shade700,
        child: SafeArea(
          child: Column(
            children: [
              // Top HUD
              _buildTopHUD(),

              // Game field
              Expanded(
                child: _buildGameField(),
              ),

              // Bottom controls
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.green.shade800,
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.of(context).pop({
                'treasures': _game.treasures,
                'score': _game.treasures,
                'correct': _game.correctPasses,
                'total': _game.totalAttempts,
                'duration': widget.gameDuration.inSeconds - _timeRemaining,
              });
            },
          ),

          // Route display
          Expanded(
            child: _buildRouteDisplay(),
          ),

          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _timeRemaining <= 10
                  ? Colors.red.shade400
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 18,
                  color: _timeRemaining <= 10 ? Colors.white : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _timeRemaining <= 10 ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Treasure count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💎', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                Text(
                  '${_game.treasures}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDisplay() {
    final route = _game.currentRoute;
    if (route == null) return const SizedBox();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🧑‍⚖️ ', style: TextStyle(fontSize: 20)),
          ...List.generate(route.playerNumbers.length, (index) {
            final number = route.playerNumbers[index];
            final status = route.getStepStatus(index);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRouteStep(number.toString(), status),
                const Text(' → ',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            );
          }),
          _buildRouteStep(
            '🥅',
            route.isReadyForGoal
                ? RouteStepStatus.current
                : RouteStepStatus.upcoming,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep(String text, RouteStepStatus status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case RouteStepStatus.completed:
        bgColor = Colors.green.shade400;
        textColor = Colors.white;
        break;
      case RouteStepStatus.current:
        bgColor = Colors.white;
        textColor = Colors.green.shade800;
        break;
      case RouteStepStatus.upcoming:
        bgColor = Colors.grey.shade600;
        textColor = Colors.white70;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildGameField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldSize = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onPanStart: _handlePanStart,
          onPanUpdate: (details) => _handlePanUpdate(details, fieldSize),
          onPanEnd: _handlePanEnd,
          onTap: _handleTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Stack(
              children: [
                // Field markings
                _buildFieldMarkings(fieldSize),

                // Goals
                _buildGoal(fieldSize, isLeft: true),
                _buildGoal(fieldSize, isLeft: false),

                // Field players
                ..._game.players.map((player) =>
                    _buildFieldPlayer(player, fieldSize)),

                // Ball with aim arrow
                _buildBall(fieldSize),

                // Player character (blue)
                _buildPlayerCharacter(fieldSize),

                // Feedback message
                if (_showFeedback && _feedbackMessage != null)
                  _buildFeedbackOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFieldMarkings(Size fieldSize) {
    return CustomPaint(
      size: fieldSize,
      painter: _FieldMarkingsPainter(),
    );
  }

  Widget _buildGoal(Size fieldSize, {required bool isLeft}) {
    final x = isLeft ? 0.0 : fieldSize.width - 30;
    final y = fieldSize.height * 0.35;
    final height = fieldSize.height * 0.3;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: 30,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 4),
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? Radius.zero : const Radius.circular(8),
            right: isLeft ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        child: const Center(
          child: Text('🥅', style: TextStyle(fontSize: 24)),
        ),
      ),
    );
  }

  Widget _buildFieldPlayer(FieldPlayer player, Size fieldSize) {
    final x = player.position.dx * fieldSize.width;
    final y = player.position.dy * fieldSize.height;
    final isHighlighted = player.id == _highlightedPlayerId;

    return Positioned(
      left: x - 30,
      top: y - 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Jersey number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.yellow : Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isHighlighted
                  ? [
                      BoxShadow(
                        color: Colors.yellow.withOpacity(0.8),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '${player.jerseyNumber}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isHighlighted ? Colors.black : Colors.green.shade800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Player sprite or emoji
          _buildPlayerSprite(isYellow: true, size: 50),
        ],
      ),
    );
  }

  Widget _buildPlayerSprite({required bool isYellow, required double size}) {
    // Try to use image, fallback to emoji
    if (_playerImageLoaded) {
      return Image.asset(
        isYellow
            ? 'assets/images/soccer_math/player_yellow.png'
            : 'assets/images/soccer_math/player_blue.png',
        package: 'kindlewood_games',
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return Text(
            '🧒',
            style: TextStyle(fontSize: size * 0.8),
          );
        },
      );
    }
    // Emoji fallback - boy with upper body
    return Text(
      '🧒',
      style: TextStyle(fontSize: size * 0.8),
    );
  }

  Widget _buildBall(Size fieldSize) {
    Offset ballPos = _game.ball.position;

    // If ball is animating, use animated position
    if (_ballMoving && _ballTargetPosition != null) {
      return AnimatedBuilder(
        animation: _ballAnimController,
        builder: (context, child) {
          final animatedPos = _ballAnimation.value;
          return Positioned(
            left: animatedPos.dx * fieldSize.width - 15,
            top: animatedPos.dy * fieldSize.height - 15,
            child: const Text('⚽', style: TextStyle(fontSize: 30)),
          );
        },
      );
    }

    return Positioned(
      left: ballPos.dx * fieldSize.width - 15,
      top: ballPos.dy * fieldSize.height - 15,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Text('⚽', style: TextStyle(fontSize: 30)),
          // Aim arrow
          if (!_ballMoving)
            Positioned(
              left: 15,
              top: 15,
              child: Transform.rotate(
                angle: _aimAngle,
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red, Colors.red.withOpacity(0)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerCharacter(Size fieldSize) {
    final ballHolder = _game.ballHolder;
    if (ballHolder == null) return const SizedBox();

    final x = ballHolder.position.dx * fieldSize.width;
    final y = ballHolder.position.dy * fieldSize.height;

    return Positioned(
      left: x - 50,
      top: y - 20,
      child: _buildPlayerSprite(isYellow: false, size: 60),
    );
  }

  Widget _buildFeedbackOverlay() {
    final isPositive = _feedbackMessage?.contains('Great') == true ||
        _feedbackMessage?.contains('GOAL') == true;

    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isPositive
                ? Colors.green.shade400
                : Colors.orange.shade400,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Text(
            _feedbackMessage!,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.green.shade800,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hint button
          ElevatedButton.icon(
            onPressed: _showHint,
            icon: const Icon(Icons.help_outline, size: 18),
            label: const Text('Hint'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Kick button
          GestureDetector(
            onTap: _handleTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text('⚽', style: TextStyle(fontSize: 28)),
            ),
          ),

          const SizedBox(width: 20),

          // Hear again button
          ElevatedButton.icon(
            onPressed: _announceCurrentTarget,
            icon: const Icon(Icons.volume_up, size: 18),
            label: const Text('Hear'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade400,
              Colors.green.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Celebration
                  const Text('🎉', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  const Text(
                    'Great Job!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Treasures
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.shade300, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Treasures Collected',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💎', style: TextStyle(fontSize: 36)),
                            const SizedBox(width: 8),
                            Text(
                              '${_game.treasures}',
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

                  // Stats
                  Text(
                    '${_game.routesCompleted} routes completed',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  Text(
                    '${_game.correctPasses}/${_game.totalAttempts} successful passes',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Close button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'treasures': _game.treasures,
                        'score': _game.treasures,
                        'correct': _game.correctPasses,
                        'total': _game.totalAttempts,
                        'duration':
                            widget.gameDuration.inSeconds - _timeRemaining,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Game state enum
enum GameState {
  intro,
  playing,
  ended,
}

/// Custom painter for field markings
class _FieldMarkingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Center line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Center circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.15,
      paint,
    );

    // Goal boxes (left)
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.25, size.width * 0.15, size.height * 0.5),
      paint,
    );

    // Goal boxes (right)
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.85, size.height * 0.25, size.width * 0.15,
          size.height * 0.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
