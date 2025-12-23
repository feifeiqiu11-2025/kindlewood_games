/// Model for a passing route in the Soccer Math game
class GameRoute {
  final List<int> playerNumbers; // Jersey numbers to pass to (excluding goal)
  final bool endsWithGoal; // Always true for Level 1
  final int currentStep; // 0-indexed current position in route

  const GameRoute({
    required this.playerNumbers,
    this.endsWithGoal = true,
    this.currentStep = 0,
  });

  /// Total number of steps including goal
  int get totalSteps => playerNumbers.length + (endsWithGoal ? 1 : 0);

  /// Check if route is complete (all passes done, ready for goal)
  bool get isReadyForGoal => currentStep >= playerNumbers.length && endsWithGoal;

  /// Check if the entire route (including goal) is complete
  bool get isComplete => currentStep >= totalSteps;

  /// Get current target number (null if ready for goal or complete)
  int? get currentTargetNumber {
    if (currentStep >= playerNumbers.length) return null;
    return playerNumbers[currentStep];
  }

  /// Create a copy with updated step
  GameRoute copyWith({
    List<int>? playerNumbers,
    bool? endsWithGoal,
    int? currentStep,
  }) {
    return GameRoute(
      playerNumbers: playerNumbers ?? this.playerNumbers,
      endsWithGoal: endsWithGoal ?? this.endsWithGoal,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  /// Advance to next step
  GameRoute advance() {
    return copyWith(currentStep: currentStep + 1);
  }

  /// Check if a jersey number is the current target
  bool isCurrentTarget(int jerseyNumber) {
    return currentTargetNumber == jerseyNumber;
  }

  /// Get step status for display
  RouteStepStatus getStepStatus(int stepIndex) {
    if (stepIndex < currentStep) return RouteStepStatus.completed;
    if (stepIndex == currentStep) return RouteStepStatus.current;
    return RouteStepStatus.upcoming;
  }

  @override
  String toString() => 'GameRoute($playerNumbers → GOAL, step: $currentStep)';
}

/// Status of a route step for UI display
enum RouteStepStatus {
  completed, // Green
  current,   // White/highlighted
  upcoming,  // Gray
}
