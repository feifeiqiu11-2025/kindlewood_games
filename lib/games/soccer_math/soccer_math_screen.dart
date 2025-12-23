import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

import 'soccer_math_game.dart';
import 'models/ball.dart';
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

  // Audio - using TTS for feedback
  late FlutterTts _tts;
  Completer<void>? _ttsCompleter;

  // Sound effects
  final AudioPlayer _kickSound = AudioPlayer();
  final AudioPlayer _goalSound = AudioPlayer();

  // Game state
  GameState _gameState = GameState.intro;
  String _countdownText = '';
  int _timeRemaining = 120;
  Timer? _gameTimer;

  // Aiming state
  double _aimAngle = 0.0;
  bool _isDragging = false;

  // Ball repositioning state
  bool _isRepositioningBall = false;

  // Animation state
  bool _ballMoving = false;
  Offset? _ballTargetPosition;
  late AnimationController _ballAnimController;
  late Animation<Offset> _ballAnimation;

  // Feedback state
  String? _feedbackMessage;
  bool _showFeedback = false;
  int? _highlightedPlayerId;

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

    // Start intro sequence
    _startIntroSequence();
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

    // Load sound effects - soft, kid-friendly sounds
    try {
      // Soft kick sound - same gentle pop as space combat
      await _kickSound.setUrl(
          'https://cdn.freesound.org/previews/341/341695_5858296-lq.mp3');
      await _kickSound.setVolume(0.2);

      // Goal celebration sound - cheerful success sound
      await _goalSound.setUrl(
          'https://cdn.freesound.org/previews/270/270402_5123851-lq.mp3');
      await _goalSound.setVolume(0.3);
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

  Future<void> _startIntroSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _speakAndWait('Follow the route to score!');
    await Future.delayed(const Duration(milliseconds: 300));

    // Countdown - use speakAndWait to ensure audio plays
    for (final num in ['3', '2', '1']) {
      if (!mounted) return;
      setState(() => _countdownText = num);
      await _speakAndWait(num);
      await Future.delayed(const Duration(milliseconds: 200));
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

  /// Get the ball center position in screen coordinates
  /// Simple: just multiply normalized position by field size
  Offset _getBallScreenPos(Size fieldSize) {
    return Offset(
      _game.ball.position.dx * fieldSize.width,
      _game.ball.position.dy * fieldSize.height,
    );
  }

  /// Get the arrow handle position in screen coordinates
  /// Ball is 50px, arrow is 50px, handle radius is 15px
  Offset _getArrowTipPosition(Size fieldSize) {
    final ballScreenPos = _getBallScreenPos(fieldSize);
    const ballRadius = 25.0; // Half of 50px ball
    const arrowLength = 50.0;
    const handleRadius = 15.0;
    final totalDistance = ballRadius + arrowLength + handleRadius;
    return Offset(
      ballScreenPos.dx + cos(_aimAngle) * totalDistance,
      ballScreenPos.dy + sin(_aimAngle) * totalDistance,
    );
  }

  void _handleTap() {
    if (_gameState != GameState.playing || _ballMoving) return;

    // Save ball position BEFORE processing kick (game logic may change it)
    final ballStartPos = _game.ball.position;

    // Process the kick
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
        // Play soft kick sound for passes, goal sound for goals
        if (result.type == KickResultType.goalScored) {
          _playSound(_goalSound);
        } else {
          _playSound(_kickSound);
        }
        _animateBallFrom(ballStartPos, result.targetPosition!);
        if (result.type == KickResultType.goalScored) {
          _speak('Goal!');
          // Stay at goal for 1.5 seconds, then move to new holder position
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              // Sync ball position with new ball holder from game logic
              final newHolder = _game.ballHolder;
              if (newHolder != null) {
                setState(() {
                  _game.ball = Ball(position: newHolder.position);
                });
              }
            }
          });
          // Announce next route after ball has moved to new position
          Future.delayed(const Duration(milliseconds: 2000), () {
            if (mounted) {
              _announceCurrentTarget();
            }
          });
        } else {
          _speak('Good job!');
          // 1 second delay before announcing next target
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) {
              _announceCurrentTarget();
            }
          });
        }
        break;

      case KickResultType.wrongTarget:
        // Gentle audio feedback for wrong target
        _speak('Oops! Try again.');
        break;
      case KickResultType.missedAll:
        // Gentle audio feedback for miss
        _speak('Try again!');
        break;
    }

    // Hide feedback after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showFeedback = false);
      }
    });
  }

  void _animateBallFrom(Offset start, Offset target) {
    setState(() {
      _ballMoving = true;
      _ballTargetPosition = target;
      // Set ball to start position for animation
      _game.ball = Ball(position: start);
    });

    _ballAnimation = Tween<Offset>(
      begin: start,
      end: target,
    ).animate(CurvedAnimation(
      parent: _ballAnimController,
      curve: Curves.easeOut,
    ));

    // Update ball position after animation completes
    _ballAnimController.forward(from: 0).then((_) {
      if (mounted) {
        _game.ball = Ball(position: target);
      }
    });
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

  /// Play a sound effect
  Future<void> _playSound(AudioPlayer player) async {
    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (e) {
      // Ignore sound errors
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _ballAnimController.dispose();
    _tts.stop();
    _kickSound.dispose();
    _goalSound.dispose();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Detect landscape vs portrait
              final isLandscape = constraints.maxWidth > constraints.maxHeight;

              if (isLandscape) {
                // Landscape: controls on the sides, field in center
                return Row(
                  children: [
                    // Left side: Back button and hint
                    Container(
                      width: 70,
                      color: Colors.green.shade800,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => _exitGame(),
                          ),
                          ElevatedButton(
                            onPressed: _showHint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.all(12),
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.help_outline, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    // Center: Field with HUD overlay
                    Expanded(
                      child: Column(
                        children: [
                          // Compact top HUD for landscape
                          _buildLandscapeTopHUD(),
                          // Field
                          Expanded(child: _buildGameField()),
                        ],
                      ),
                    ),

                    // Right side: Kick button and hear
                    Container(
                      width: 70,
                      color: Colors.green.shade800,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Timer and treasures
                          _buildCompactStats(),
                          const SizedBox(height: 16),
                          // Kick button
                          GestureDetector(
                            onTap: _handleTap,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: const Text('⚽', style: TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Hear button
                          ElevatedButton(
                            onPressed: _announceCurrentTarget,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.all(12),
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.volume_up, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Portrait: original layout
              return Column(
                children: [
                  _buildTopHUD(),
                  Expanded(child: _buildGameField()),
                  _buildBottomControls(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _exitGame() {
    Navigator.of(context).pop({
      'treasures': _game.treasures,
      'score': _game.treasures,
      'correct': _game.correctPasses,
      'total': _game.totalAttempts,
      'duration': widget.gameDuration.inSeconds - _timeRemaining,
    });
  }

  Widget _buildLandscapeTopHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.green.shade800.withOpacity(0.9),
      child: _buildRouteDisplay(),
    );
  }

  Widget _buildCompactStats() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Timer
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _timeRemaining <= 10 ? Colors.red.shade400 : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _timeRemaining <= 10 ? Colors.white : Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Treasures
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              const Text('💎', style: TextStyle(fontSize: 16)),
              Text(
                '${_game.treasures}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.green.shade800,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First row: Back button, Route display
          Row(
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _exitGame,
              ),
              const SizedBox(width: 8),

              // Route display - takes full width
              Expanded(
                child: _buildRouteDisplay(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Second row: Timer and Treasures (centered)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                      size: 16,
                      color: _timeRemaining <= 10 ? Colors.white : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_timeRemaining ~/ 60}:${(_timeRemaining % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _timeRemaining <= 10 ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Treasure count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '${_game.treasures}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

        return Container(
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Stack(
            clipBehavior: Clip.none, // Allow arrow handle to extend outside field
            children: [
              // Field markings
              _buildFieldMarkings(fieldSize),

              // Goals
              _buildGoal(fieldSize, isLeft: true),
              _buildGoal(fieldSize, isLeft: false),

              // Field players
              ..._game.players.map((player) =>
                  _buildFieldPlayer(player, fieldSize)),

              // Ball with aim arrow (includes its own gesture detectors)
              ..._buildBallAndArrow(fieldSize),

              // Feedback message
              if (_showFeedback && _feedbackMessage != null)
                _buildFeedbackOverlay(),
            ],
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
    final isBallHolder = player.id == _game.ballHolderId;

    // Ball holder is shown with the ball, skip rendering here
    if (isBallHolder) return const SizedBox.shrink();

    // Field players shown with yellow jersey image and number
    return Positioned(
      left: x - 28,
      top: y - 35,
      child: SizedBox(
        width: 56,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Highlight glow if hinted
            if (isHighlighted)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.8),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            // Player image - yellow jersey for field players (transparent background)
            Image.asset(
              'assets/images/soccer_math/player_yellow.png',
              package: 'kindlewood_games',
              width: 56,
              height: 60,
              fit: BoxFit.contain,
            ),
            // Jersey number on upper body (chest area)
            Positioned(
              top: 28,
              child: Text(
                '${player.jerseyNumber}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    // Dark outline for contrast on yellow jersey
                    Shadow(color: Colors.black, blurRadius: 0, offset: const Offset(1, 1)),
                    Shadow(color: Colors.black, blurRadius: 0, offset: const Offset(-1, -1)),
                    Shadow(color: Colors.black, blurRadius: 0, offset: const Offset(1, -1)),
                    Shadow(color: Colors.black, blurRadius: 0, offset: const Offset(-1, 1)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build ball and arrow with separate gesture detectors
  List<Widget> _buildBallAndArrow(Size fieldSize) {
    // Ball center position in screen coordinates
    final ballScreenX = _game.ball.position.dx * fieldSize.width;
    final ballScreenY = _game.ball.position.dy * fieldSize.height;
    const ballVisualSize = 44.0; // Visual ball size
    const ballTouchSize = 60.0; // Larger touch target

    // If ball is animating, use animated position
    if (_ballMoving && _ballTargetPosition != null) {
      return [
        AnimatedBuilder(
          animation: _ballAnimController,
          builder: (context, child) {
            final animatedPos = _ballAnimation.value;
            final ax = animatedPos.dx * fieldSize.width;
            final ay = animatedPos.dy * fieldSize.height;

            // Calculate direction for player orientation
            final startPos = _game.ball.position;
            final endPos = _ballTargetPosition!;
            final dirAngle = atan2(endPos.dy - startPos.dy, endPos.dx - startPos.dx);

            return Stack(
              children: [
                // Player chasing ball (blue jersey - ball holder)
                Positioned(
                  left: ax - cos(dirAngle) * 25 - 22,
                  top: ay - sin(dirAngle) * 25 - 35,
                  child: SizedBox(
                    width: 44,
                    height: 50,
                    child: Image.asset(
                      'assets/images/soccer_math/player_blue.png',
                      package: 'kindlewood_games',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // Ball
                Positioned(
                  left: ax - ballVisualSize / 2,
                  top: ay - ballVisualSize / 2,
                  child: SizedBox(
                    width: ballVisualSize,
                    height: ballVisualSize,
                    child: const Center(
                      child: Text('⚽', style: TextStyle(fontSize: 36)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ];
    }

    // Get ball holder for movement zone
    final holder = _game.ballHolder;

    // CLEAN CHEVRON DESIGN:
    // Ball --[small gap]--[chevron handle]
    // Chevron is close to ball, easy to drag

    const gapFromBall = 8.0; // Small gap from ball edge
    const handleSize = 44.0; // Chevron button size

    // Handle center position - close to ball
    final handleCenterX = ballScreenX + cos(_aimAngle) * (ballVisualSize / 2 + gapFromBall + handleSize / 2);
    final handleCenterY = ballScreenY + sin(_aimAngle) * (ballVisualSize / 2 + gapFromBall + handleSize / 2);

    // Short line from ball to chevron
    final lineStartX = ballScreenX + cos(_aimAngle) * (ballVisualSize / 2 + 4);
    final lineStartY = ballScreenY + sin(_aimAngle) * (ballVisualSize / 2 + 4);
    final lineEndX = handleCenterX - cos(_aimAngle) * (handleSize / 2 - 4);
    final lineEndY = handleCenterY - sin(_aimAngle) * (handleSize / 2 - 4);

    return [
      // Movement zone indicator (always show when ball holder exists)
      if (holder != null)
        Positioned(
          left: (holder.position.dx - 0.10) * fieldSize.width,
          top: (holder.position.dy - 0.10) * fieldSize.height,
          child: IgnorePointer(
            child: Container(
              width: 0.20 * fieldSize.width,
              height: 0.20 * fieldSize.height,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isRepositioningBall
                      ? Colors.yellow.withOpacity(0.8)
                      : Colors.white.withOpacity(0.3),
                  width: _isRepositioningBall ? 3 : 1,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _isRepositioningBall
                    ? Colors.yellow.withOpacity(0.15)
                    : Colors.transparent,
              ),
              child: _isRepositioningBall
                  ? const Center(
                      child: Text(
                        'Drag here',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),

      // Simple line from ball to chevron (no border, just solid color)
      if (!_ballMoving)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SimpleLinePainter(
                start: Offset(lineStartX, lineStartY),
                end: Offset(lineEndX, lineEndY),
                color: Colors.red.shade700,
                strokeWidth: 3.0,
              ),
            ),
          ),
        ),

      // Player kicking the ball (blue jersey - ball holder, behind the ball)
      Positioned(
        left: ballScreenX - cos(_aimAngle) * 25 - 22,
        top: ballScreenY - sin(_aimAngle) * 25 - 35,
        child: IgnorePointer(
          child: SizedBox(
            width: 44,
            height: 50,
            child: Image.asset(
              'assets/images/soccer_math/player_blue.png',
              package: 'kindlewood_games',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),

      // Ball with its own GestureDetector for dragging
      Positioned(
        left: ballScreenX - ballTouchSize / 2,
        top: ballScreenY - ballTouchSize / 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            if (_gameState != GameState.playing || _ballMoving) return;
            print('🏀 Ball drag START at ${details.localPosition}');
            setState(() => _isRepositioningBall = true);
          },
          onPanUpdate: (details) {
            if (!_isRepositioningBall || holder == null) return;
            print('🏀 Ball drag UPDATE delta: ${details.delta}');

            // Use delta to move ball position
            final currentX = _game.ball.position.dx;
            final currentY = _game.ball.position.dy;

            var newX = currentX + details.delta.dx / fieldSize.width;
            var newY = currentY + details.delta.dy / fieldSize.height;

            // Clamp to movement zone around holder
            const maxOffset = 0.10;
            newX = newX.clamp(holder.position.dx - maxOffset, holder.position.dx + maxOffset);
            newY = newY.clamp(holder.position.dy - maxOffset, holder.position.dy + maxOffset);

            // Keep within field bounds
            newX = newX.clamp(0.12, 0.88);
            newY = newY.clamp(0.1, 0.9);

            setState(() {
              _game.ball = _game.ball.copyWith(position: Offset(newX, newY));
            });
          },
          onPanEnd: (_) {
            print('🏀 Ball drag END');
            setState(() => _isRepositioningBall = false);
          },
          child: Container(
            width: ballTouchSize,
            height: ballTouchSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRepositioningBall ? Colors.yellow.withOpacity(0.3) : Colors.transparent,
              border: _isRepositioningBall
                  ? Border.all(color: Colors.yellow, width: 3)
                  : null,
            ),
            child: const Center(
              child: Text('⚽', style: TextStyle(fontSize: 36)),
            ),
          ),
        ),
      ),

      // Arrow drag handle - the circular KICK button at end of arrow
      if (!_ballMoving)
        Positioned(
          left: handleCenterX - handleSize / 2,
          top: handleCenterY - handleSize / 2,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (details) {
              if (_gameState != GameState.playing || _ballMoving) return;
              print('🎯 Handle drag START');
              setState(() => _isDragging = true);
            },
            onPanUpdate: (details) {
              if (!_isDragging) return;

              // Get current handle position and add delta
              final newHandleX = handleCenterX + details.delta.dx;
              final newHandleY = handleCenterY + details.delta.dy;

              // Calculate angle from ball center to new handle position
              final dx = newHandleX - ballScreenX;
              final dy = newHandleY - ballScreenY;

              setState(() {
                _aimAngle = atan2(dy, dx);
              });
            },
            onPanEnd: (_) {
              print('🎯 Handle drag END');
              setState(() => _isDragging = false);
            },
            onTap: _handleTap,
            child: Transform.rotate(
              angle: _aimAngle,
              child: SizedBox(
                width: handleSize,
                height: handleSize,
                child: Center(
                  // Double arrow chevron - clean and visible
                  child: Icon(
                    Icons.double_arrow,
                    size: 36,
                    color: _isDragging ? Colors.orange : Colors.red.shade700,
                    shadows: const [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 3,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
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
                    onPressed: _exitGame,
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

/// Simple line painter - just a solid color line, no border
class _SimpleLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  _SimpleLinePainter({
    required this.start,
    required this.end,
    required this.color,
    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _SimpleLinePainter oldDelegate) {
    return start != oldDelegate.start || end != oldDelegate.end;
  }
}

/// Custom painter for arrow head (unused but kept for reference)
class _ArrowHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
