import 'package:flutter/material.dart';
import 'package:kindlewood_games/kindlewood_games.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Rain Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.lightBlue.shade300,
              Colors.lightBlue.shade100,
              Colors.green.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // Word Rain illustration - more words falling like real game
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      // Clouds at top
                      Positioned(top: 0, left: 20, child: Icon(Icons.cloud, size: 60, color: Colors.white.withOpacity(0.9))),
                      Positioned(top: 10, right: 30, child: Icon(Icons.cloud, size: 50, color: Colors.white.withOpacity(0.8))),
                      Positioned(top: 5, child: Icon(Icons.cloud, size: 70, color: Colors.white)),
                      // Falling words at different heights
                      Positioned(top: 50, left: 30, child: _buildFallingWordPreview('🐱', 'cat')),
                      Positioned(top: 80, left: 100, child: _buildFallingWordPreview('⭐', 'star')),
                      Positioned(top: 60, right: 40, child: _buildFallingWordPreview('🌳', 'tree')),
                      Positioned(top: 120, left: 60, child: _buildFallingWordPreview('🐕', 'dog')),
                      Positioned(top: 140, right: 80, child: _buildFallingWordPreview('☀️', 'sun')),
                      Positioned(top: 100, child: _buildFallingWordPreview('🐦', 'bird')),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Word Rain',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.volume_up, color: Colors.orange.shade400, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tap the word you hear!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                // Level buttons
                _buildLevelButton(
                  context,
                  level: 1,
                  label: 'Easy',
                  subtitle: 'With pictures',
                  color: Colors.green,
                  icon: Icons.star,
                ),
                const SizedBox(height: 16),
                _buildLevelButton(
                  context,
                  level: 2,
                  label: 'Medium',
                  subtitle: 'Words only',
                  color: Colors.orange,
                  icon: Icons.star,
                ),
                const SizedBox(height: 16),
                _buildLevelButton(
                  context,
                  level: 3,
                  label: 'Hard',
                  subtitle: 'Fast & tricky',
                  color: Colors.red.shade400,
                  icon: Icons.star,
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelButton(
    BuildContext context, {
    required int level,
    required String label,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => _playGame(context, level),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                level,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(icon, color: Colors.yellow.shade200, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallingWordPreview(String emoji, String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          Text(
            word,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _playGame(BuildContext context, int level) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordRainScreen(
          words: [
            'cat', 'dog', 'bird', 'fish', 'tree',
            'sun', 'moon', 'star', 'cloud', 'rain',
            'red', 'blue', 'green', 'yellow', 'orange',
            'one', 'two', 'three', 'four', 'five',
            'happy', 'sad', 'big', 'small', 'fast',
          ],
          level: level,
          gameDuration: const Duration(minutes: 1),
          onGameEnd: (score, correct, total) {
            debugPrint('Game ended - Score: $score, Correct: $correct/$total');
          },
        ),
      ),
    );
  }
}
