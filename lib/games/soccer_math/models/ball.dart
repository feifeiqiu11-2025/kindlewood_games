import 'dart:math';
import 'dart:ui';

/// Model for the ball in the Soccer Math game
class Ball {
  final Offset position; // Normalized position (0.0 to 1.0)
  final double aimAngle; // Radians, 0 = right, PI/2 = down
  final bool isMoving;
  final Offset? targetPosition; // Where the ball is heading

  const Ball({
    required this.position,
    this.aimAngle = 0.0,
    this.isMoving = false,
    this.targetPosition,
  });

  /// Create a copy with updated values
  Ball copyWith({
    Offset? position,
    double? aimAngle,
    bool? isMoving,
    Offset? targetPosition,
  }) {
    return Ball(
      position: position ?? this.position,
      aimAngle: aimAngle ?? this.aimAngle,
      isMoving: isMoving ?? this.isMoving,
      targetPosition: targetPosition ?? this.targetPosition,
    );
  }

  /// Get the direction vector based on aim angle
  Offset get aimDirection {
    return Offset(cos(aimAngle), sin(aimAngle));
  }

  @override
  String toString() => 'Ball(pos: $position, angle: $aimAngle, moving: $isMoving)';
}
