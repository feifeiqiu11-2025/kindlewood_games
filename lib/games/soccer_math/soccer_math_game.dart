import 'dart:math';
import 'dart:ui';

import 'models/field_player.dart';
import 'models/ball.dart';
import 'models/game_route.dart';

/// Core game logic for Soccer Math
class SoccerMathGame {
  final int level;
  final Duration gameDuration;
  final int playerCount;
  final Random _random = Random();

  // Game state
  List<FieldPlayer> players = [];
  Ball ball = const Ball(position: Offset(0.5, 0.5));
  GameRoute? currentRoute;
  int? ballHolderId; // ID of player holding the ball

  // Scoring
  int treasures = 0;
  int correctPasses = 0;
  int totalAttempts = 0;
  int routesCompleted = 0;

  // Constants - HUGE hit zones for kids (field is 0-1 normalized)
  static const double playerHitRadius = 0.35; // Almost half the field width
  static const double goalHitRadius = 0.40; // Even larger for goals

  SoccerMathGame({
    this.level = 1,
    this.gameDuration = const Duration(minutes: 2),
    this.playerCount = 8,
  });

  /// Initialize the game field with players
  void initializeField() {
    players = _generatePlayers();
    _assignBallToRandomPlayer();
    currentRoute = _generateRoute();
  }

  /// Generate players with random positions and unique jersey numbers
  List<FieldPlayer> _generatePlayers() {
    final List<FieldPlayer> result = [];
    final usedNumbers = <int>{};
    final usedPositions = <Offset>[];

    // Define safe zones (avoid goals on left/right edges)
    // Field is normalized 0-1, goals are at x=0.05 and x=0.95
    const minX = 0.15;
    const maxX = 0.85;
    const minY = 0.15;
    const maxY = 0.85;

    for (int i = 0; i < playerCount; i++) {
      // Generate unique jersey number (1-20)
      int jerseyNumber;
      do {
        jerseyNumber = _random.nextInt(20) + 1;
      } while (usedNumbers.contains(jerseyNumber));
      usedNumbers.add(jerseyNumber);

      // Generate position with minimum spacing
      Offset position;
      int attempts = 0;
      do {
        position = Offset(
          minX + _random.nextDouble() * (maxX - minX),
          minY + _random.nextDouble() * (maxY - minY),
        );
        attempts++;
      } while (_isTooCloseToOthers(position, usedPositions) && attempts < 50);

      usedPositions.add(position);

      result.add(FieldPlayer(
        id: i,
        jerseyNumber: jerseyNumber,
        position: position,
      ));
    }

    return result;
  }

  /// Check if a position is too close to existing positions
  bool _isTooCloseToOthers(Offset position, List<Offset> others) {
    const minDistance = 0.15; // Minimum spacing between players
    for (final other in others) {
      final dx = (position.dx - other.dx).abs();
      final dy = (position.dy - other.dy).abs();
      if (dx < minDistance && dy < minDistance) {
        return true;
      }
    }
    return false;
  }

  /// Assign the ball to a random player
  void _assignBallToRandomPlayer() {
    final randomPlayer = players[_random.nextInt(players.length)];
    ballHolderId = randomPlayer.id;
    ball = Ball(position: randomPlayer.position);
  }

  /// Generate a route with 3-5 passes plus goal
  GameRoute _generateRoute() {
    final routeLength = 3 + _random.nextInt(3); // 3, 4, or 5
    final routeNumbers = <int>[];
    final availableNumbers = players
        .where((p) => p.id != ballHolderId) // Exclude current ball holder
        .map((p) => p.jerseyNumber)
        .toList();

    // Shuffle and pick route numbers
    availableNumbers.shuffle(_random);

    for (int i = 0; i < routeLength && i < availableNumbers.length; i++) {
      routeNumbers.add(availableNumbers[i]);
    }

    return GameRoute(playerNumbers: routeNumbers);
  }

  /// Get the player currently holding the ball
  FieldPlayer? get ballHolder {
    if (ballHolderId == null) return null;
    return players.firstWhere(
      (p) => p.id == ballHolderId,
      orElse: () => players.first,
    );
  }

  /// Process a kick attempt and return the result
  /// SIMPLE APPROACH: Only check if the TARGET is hit, ignore other players
  KickResult processKick(double aimAngle) {
    totalAttempts++;

    // Calculate kick direction
    final direction = Offset(cos(aimAngle), sin(aimAngle));
    final startPos = ball.position;

    // Debug: print kick info
    print('⚽ Kick from ${startPos.dx.toStringAsFixed(2)}, ${startPos.dy.toStringAsFixed(2)}');
    print('⚽ Angle: ${(aimAngle * 180 / 3.14159).toStringAsFixed(1)}°');

    // Check if ready for goal
    if (currentRoute?.isReadyForGoal == true) {
      // Check if aiming at either goal
      if (_isAimingAtGoal(startPos, direction)) {
        treasures++;
        routesCompleted++;
        correctPasses++;

        // Generate new route
        _assignBallToRandomPlayer();
        currentRoute = _generateRoute();

        return KickResult(
          type: KickResultType.goalScored,
          message: "GOAL! Great job!",
          targetPosition: direction.dx > 0 ? const Offset(0.95, 0.5) : const Offset(0.05, 0.5),
        );
      }
    }

    // Find the target player
    final targetNumber = currentRoute?.currentTargetNumber;
    if (targetNumber == null) {
      return KickResult(
        type: KickResultType.missedAll,
        message: "Oops! Try again!",
      );
    }

    // Find target player
    final targetPlayer = players.firstWhere(
      (p) => p.jerseyNumber == targetNumber,
      orElse: () => players.first,
    );

    print('⚽ Target: #$targetNumber at (${targetPlayer.position.dx.toStringAsFixed(2)}, ${targetPlayer.position.dy.toStringAsFixed(2)})');

    // Check if aiming at target player (VERY generous)
    if (_isAimingAtPlayer(startPos, direction, targetPlayer)) {
      // Correct pass!
      correctPasses++;
      ballHolderId = targetPlayer.id;
      // DON'T update ball position here - let animation handle it
      // ball = Ball(position: targetPlayer.position);
      currentRoute = currentRoute!.advance();

      final isLastPass = currentRoute!.isReadyForGoal;
      return KickResult(
        type: KickResultType.correctPass,
        message: isLastPass ? "Now shoot to goal!" : "Great pass!",
        targetPosition: targetPlayer.position,
        hitPlayer: targetPlayer,
      );
    } else {
      // Wrong direction
      return KickResult(
        type: KickResultType.wrongTarget,
        message: "Oops! Find number $targetNumber",
      );
    }
  }

  /// Check if aiming at a specific player (very generous)
  bool _isAimingAtPlayer(Offset start, Offset direction, FieldPlayer player) {
    final toPlayer = Offset(
      player.position.dx - start.dx,
      player.position.dy - start.dy,
    );

    // Normalize direction
    final dirLen = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);
    final normDir = Offset(direction.dx / dirLen, direction.dy / dirLen);

    // Normalize to player
    final playerLen = sqrt(toPlayer.dx * toPlayer.dx + toPlayer.dy * toPlayer.dy);
    final normToPlayer = Offset(toPlayer.dx / playerLen, toPlayer.dy / playerLen);

    // Dot product - how aligned are they? (1.0 = perfect, 0 = perpendicular, -1 = opposite)
    final dot = normDir.dx * normToPlayer.dx + normDir.dy * normToPlayer.dy;

    print('⚽ Aiming check: dot=${ dot.toStringAsFixed(3)} (need > 0.5)');

    // Very generous - just need to be roughly pointing at them (within ~60 degrees)
    return dot > 0.5;
  }

  /// Check if aiming at a goal
  bool _isAimingAtGoal(Offset start, Offset direction) {
    // Normalize direction
    final dirLen = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);
    final normDir = Offset(direction.dx / dirLen, direction.dy / dirLen);

    // Check horizontal component - must be strongly left or right
    return normDir.dx.abs() > 0.5;
  }

  /// Find the first target hit along a direction
  _HitResult? _findHitTarget(Offset start, Offset direction) {
    // Normalize direction
    final len = sqrt(direction.dx * direction.dx + direction.dy * direction.dy);
    final normDir = Offset(direction.dx / len, direction.dy / len);

    // Check goals first (at x = 0.05 for left, x = 0.95 for right)
    // Goals are vertically centered (y = 0.4 to 0.6)
    final goalY = 0.5;
    const goalHalfHeight = 0.15;

    // Left goal (x = 0.05)
    if (normDir.dx < -0.1) {
      final t = (0.05 - start.dx) / normDir.dx;
      if (t > 0) {
        final hitY = start.dy + t * normDir.dy;
        if ((hitY - goalY).abs() < goalHalfHeight) {
          return _HitResult(
            isGoal: true,
            position: Offset(0.05, hitY),
            distance: t,
          );
        }
      }
    }

    // Right goal (x = 0.95)
    if (normDir.dx > 0.1) {
      final t = (0.95 - start.dx) / normDir.dx;
      if (t > 0) {
        final hitY = start.dy + t * normDir.dy;
        if ((hitY - goalY).abs() < goalHalfHeight) {
          return _HitResult(
            isGoal: true,
            position: Offset(0.95, hitY),
            distance: t,
          );
        }
      }
    }

    // Check players
    FieldPlayer? closestPlayer;
    double closestDistance = double.infinity;

    for (final player in players) {
      if (player.id == ballHolderId) continue; // Skip ball holder

      // Simple distance check along ray
      final toPlayer = Offset(
        player.position.dx - start.dx,
        player.position.dy - start.dy,
      );

      // Project onto direction
      final projection = toPlayer.dx * normDir.dx + toPlayer.dy * normDir.dy;
      if (projection <= 0) continue; // Behind the kick

      // Perpendicular distance
      final perpX = start.dx + projection * normDir.dx - player.position.dx;
      final perpY = start.dy + projection * normDir.dy - player.position.dy;
      final perpDist = sqrt(perpX * perpX + perpY * perpY);

      // Debug: print check for each player
      print('⚽ Checking #${player.jerseyNumber} at (${player.position.dx.toStringAsFixed(2)}, ${player.position.dy.toStringAsFixed(2)}) - proj: ${projection.toStringAsFixed(3)}, perpDist: ${perpDist.toStringAsFixed(3)}, hitRadius: $playerHitRadius');

      if (perpDist < playerHitRadius && projection < closestDistance) {
        closestDistance = projection;
        closestPlayer = player;
        print('⚽ → This is a HIT!');
      }
    }

    if (closestPlayer != null) {
      return _HitResult(
        isGoal: false,
        player: closestPlayer,
        position: closestPlayer.position,
        distance: closestDistance,
      );
    }

    return null;
  }

  /// Get accuracy percentage
  double get accuracy {
    if (totalAttempts == 0) return 0;
    return (correctPasses / totalAttempts) * 100;
  }
}

/// Result of a kick attempt
class KickResult {
  final KickResultType type;
  final String message;
  final Offset? targetPosition;
  final FieldPlayer? hitPlayer;

  const KickResult({
    required this.type,
    required this.message,
    this.targetPosition,
    this.hitPlayer,
  });
}

enum KickResultType {
  correctPass,
  goalScored,
  wrongTarget,
  missedAll,
}

/// Internal class for hit detection results
class _HitResult {
  final bool isGoal;
  final FieldPlayer? player;
  final Offset position;
  final double distance;

  _HitResult({
    required this.isGoal,
    this.player,
    required this.position,
    required this.distance,
  });
}
