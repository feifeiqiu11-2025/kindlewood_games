import 'package:flutter/material.dart';
import 'word_rain_game.dart';

/// Word Rain Game Screen
///
/// Main UI for the Word Rain game where words fall from the sky
/// and children tap the correct word they hear.

class WordRainScreen extends StatefulWidget {
  final List<String> words;
  final int level;
  final VoidCallback? onGameComplete;

  const WordRainScreen({
    super.key,
    required this.words,
    this.level = 1,
    this.onGameComplete,
  });

  @override
  State<WordRainScreen> createState() => _WordRainScreenState();
}

class _WordRainScreenState extends State<WordRainScreen> {
  late WordRainGame _game;

  @override
  void initState() {
    super.initState();
    _game = WordRainGame(
      level: widget.level,
      words: widget.words,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Word Rain - Level ${widget.level}'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                'Score: ${_game.score}',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Word Rain Game',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Coming Soon!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onGameComplete?.call();
              },
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
