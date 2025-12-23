import 'dart:ui';

/// Model for a field player in the Soccer Math game
class FieldPlayer {
  final int id;
  final int jerseyNumber;
  final Offset position; // Normalized position (0.0 to 1.0)
  final bool hasBall;

  const FieldPlayer({
    required this.id,
    required this.jerseyNumber,
    required this.position,
    this.hasBall = false,
  });

  /// Create a copy with updated values
  FieldPlayer copyWith({
    int? id,
    int? jerseyNumber,
    Offset? position,
    bool? hasBall,
  }) {
    return FieldPlayer(
      id: id ?? this.id,
      jerseyNumber: jerseyNumber ?? this.jerseyNumber,
      position: position ?? this.position,
      hasBall: hasBall ?? this.hasBall,
    );
  }

  /// Check if a point is within this player's hit zone
  bool containsPoint(Offset point, double hitRadius) {
    final dx = (point.dx - position.dx).abs();
    final dy = (point.dy - position.dy).abs();
    return dx < hitRadius && dy < hitRadius;
  }

  @override
  String toString() => 'FieldPlayer(#$jerseyNumber at $position)';
}
