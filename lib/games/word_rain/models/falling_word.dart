import 'dart:math';

/// Model for a falling word in the Word Rain game
class FallingWord {
  final String word;
  final String emoji;
  final double x; // Horizontal position (0.0 to 1.0)
  double y; // Vertical position (0.0 = top, 1.0 = bottom)
  final bool isTarget; // Is this the word to tap?
  bool isTapped = false;
  bool isCorrect = false;
  bool isWrong = false;

  FallingWord({
    required this.word,
    required this.emoji,
    required this.x,
    this.y = -0.1, // Start above the screen
    this.isTarget = false,
  });

  /// Check if a word has a valid emoji mapping (not fallback)
  static bool hasEmoji(String word) {
    return getEmoji(word) != '📝';
  }

  /// Filter words to only include those with emoji mappings
  static List<String> filterWordsWithEmojis(List<String> words) {
    return words.where((word) => hasEmoji(word)).toList();
  }

  /// Get emoji for a word
  static String getEmoji(String word) {
    const wordEmojis = {
      // Animals
      'cat': '🐱', 'dog': '🐕', 'bird': '🐦', 'fish': '🐟', 'bear': '🐻',
      'fox': '🦊', 'owl': '🦉', 'pig': '🐷', 'cow': '🐮',
      'bee': '🐝', 'ant': '🐜', 'bug': '🐛', 'frog': '🐸', 'lion': '🦁',
      'duck': '🦆', 'deer': '🦌', 'turtle': '🐢', 'rabbit': '🐰', 'elephant': '🐘',
      'monkey': '🐵', 'tiger': '🐯', 'horse': '🐴', 'sheep': '🐑', 'goat': '🐐',
      'zebra': '🦓', 'giraffe': '🦒', 'whale': '🐋', 'dolphin': '🐬', 'shark': '🦈',
      'penguin': '🐧', 'rooster': '🐓', 'eagle': '🦅', 'parrot': '🦜',
      'snake': '🐍', 'lizard': '🦎', 'dragon': '🐉', 'dinosaur': '🦕', 'crab': '🦀', 'hen': '🐔',
      'octopus': '🐙', 'squid': '🦑', 'snail': '🐌', 'spider': '🕷️', 'butterfly': '🦋',
      'mouse': '🐭', 'rat': '🐀', 'hamster': '🐹', 'bunny': '🐰', 'wolf': '🐺',
      'panda': '🐼', 'koala': '🐨', 'sloth': '🦥', 'otter': '🦦', 'skunk': '🦨',

      // Nature & Weather
      'tree': '🌳', 'sun': '☀️', 'moon': '🌙', 'cloud': '☁️',
      'rain': '🌧️', 'snow': '❄️', 'flower': '🌸', 'grass': '🌱', 'water': '💧',
      'fire': '🔥', 'rainbow': '🌈', 'mountain': '⛰️', 'volcano': '🌋', 'beach': '🏖️',
      'ocean': '🌊', 'river': '🏞️', 'forest': '🌲', 'desert': '🏜️', 'island': '🏝️',
      'wind': '💨', 'storm': '⛈️', 'lightning': '⚡', 'tornado': '🌪️', 'fog': '🌫️',
      'leaf': '🍃', 'leaves': '🍂', 'rose': '🌹', 'tulip': '🌷', 'sunflower': '🌻',
      'plant': '🪴', 'cactus': '🌵', 'palm': '🌴', 'bamboo': '🎋', 'herb': '🌿',

      // Colors
      'red': '🔴', 'blue': '🔵', 'green': '🟢', 'yellow': '🟡',
      'purple': '🟣', 'brown': '🟤', 'black': '⚫', 'white': '⚪', 'pink': '🩷',

      // Numbers
      'one': '1️⃣', 'two': '2️⃣', 'three': '3️⃣', 'four': '4️⃣', 'five': '5️⃣',
      'six': '6️⃣', 'seven': '7️⃣', 'eight': '8️⃣', 'nine': '9️⃣', 'ten': '🔟',
      'zero': '0️⃣', 'hundred': '💯',

      // Emotions & Expressions
      'happy': '😊', 'sad': '😢', 'smile': '😄', 'laugh': '😂', 'love': '❤️',
      'angry': '😠', 'scared': '😨', 'surprise': '😮', 'excited': '🤩', 'sleepy': '😴',
      'cry': '😭', 'sick': '🤢', 'worry': '😟', 'think': '🤔', 'cool': '😎',

      // Actions & Verbs
      'run': '🏃', 'jump': '🦘', 'play': '🎮', 'walk': '🚶', 'swim': '🏊',
      'dance': '💃', 'sing': '🎤', 'sleep': '😴', 'eat': '🍽️', 'drink': '🥤',
      'read': '📖', 'write': '✍️', 'draw': '🎨', 'paint': '🖌️', 'fly': '✈️',
      'climb': '🧗', 'ride': '🚴', 'drive': '🚗', 'sail': '⛵', 'ski': '⛷️',
      'help': '🤝', 'work': '💼', 'study': '📚', 'learn': '🎓', 'teach': '👨‍🏫',

      // Food & Drinks
      'apple': '🍎', 'banana': '🍌', 'orange': '🍊', 'lemon': '🍋', 'grape': '🍇',
      'watermelon': '🍉', 'strawberry': '🍓', 'cherry': '🍒', 'peach': '🍑', 'pear': '🍐',
      'pineapple': '🍍', 'mango': '🥭', 'coconut': '🥥', 'kiwi': '🥝', 'tomato': '🍅',
      'carrot': '🥕', 'corn': '🌽', 'pepper': '🌶️', 'cucumber': '🥒', 'broccoli': '🥦',
      'bread': '🍞', 'cheese': '🧀', 'egg': '🥚', 'meat': '🥩', 'chicken': '🍗',
      'pizza': '🍕', 'burger': '🍔', 'hotdog': '🌭', 'taco': '🌮', 'sandwich': '🥪',
      'pasta': '🍝', 'rice': '🍚', 'noodle': '🍜', 'soup': '🍲', 'salad': '🥗',
      'cake': '🍰', 'cookie': '🍪', 'candy': '🍬', 'chocolate': '🍫', 'honey': '🍯',
      'milk': '🥛', 'coffee': '☕', 'tea': '🍵', 'juice': '🧃', 'soda': '🥤',

      // Objects & Things
      'car': '🚗', 'bus': '🚌', 'train': '🚂', 'plane': '✈️', 'boat': '⛵',
      'bike': '🚲', 'motorcycle': '🏍️', 'truck': '🚚', 'taxi': '🚕', 'ship': '🚢',
      'house': '🏠', 'home': '🏡', 'building': '🏢', 'school': '🏫', 'castle': '🏰',
      'tower': '🗼', 'bridge': '🌉', 'tent': '⛺', 'church': '⛪', 'temple': '🛕',
      'book': '📚', 'pen': '🖊️', 'pencil': '✏️', 'paper': '📄', 'notebook': '📓',
      'bag': '🎒', 'box': '📦', 'gift': '🎁', 'balloon': '🎈', 'flag': '🚩',
      'ball': '⚽', 'toy': '🧸', 'puzzle': '🧩', 'game': '🎮', 'dice': '🎲',
      'music': '🎵', 'guitar': '🎸', 'piano': '🎹', 'drum': '🥁', 'trumpet': '🎺',
      'phone': '📱', 'computer': '💻', 'watch': '⌚', 'camera': '📷', 'light': '💡',
      'key': '🔑', 'lock': '🔒', 'door': '🚪', 'window': '🪟', 'chair': '🪑',
      'table': '🪑', 'bed': '🛏️', 'bath': '🛁', 'toilet': '🚽', 'shower': '🚿',
      'hat': '🎩', 'crown': '👑', 'glasses': '👓', 'shirt': '👕', 'pants': '👖',
      'dress': '👗', 'shoe': '👞', 'boot': '👢', 'sock': '🧦', 'glove': '🧤',

      // Sports & Activities
      'soccer': '⚽', 'basketball': '🏀', 'football': '🏈', 'baseball': '⚾', 'tennis': '🎾',
      'golf': '⛳', 'hockey': '🏒', 'cricket': '🏏', 'bowling': '🎳', 'boxing': '🥊',

      // Space & Science
      'rocket': '🚀', 'planet': '🪐', 'earth': '🌍', 'mars': '🔴',
      'comet': '☄️', 'galaxy': '🌌', 'telescope': '🔭', 'satellite': '🛰️',
      'robot': '🤖', 'alien': '👽', 'ufo': '🛸', 'atom': '⚛️', 'magnet': '🧲',

      // Tools & Items
      'hammer': '🔨', 'wrench': '🔧', 'saw': '🪚', 'scissors': '✂️', 'knife': '🔪',
      'fork': '🍴', 'spoon': '🥄', 'plate': '🍽️', 'cup': '☕', 'bottle': '🍼',
      'coin': '🪙', 'money': '💰', 'gem': '💎', 'ring': '💍', 'medal': '🏅',
      'trophy': '🏆', 'award': '🥇', 'ticket': '🎟️', 'paint': '🎨', 'brush': '🖌️',

      // Places & Buildings
      'park': '🏞️', 'playground': '🛝', 'farm': '🚜', 'zoo': '🦁', 'circus': '🎪',
      'museum': '🏛️', 'hospital': '🏥', 'store': '🏪', 'market': '🏪', 'restaurant': '🍽️',
      'hotel': '🏨', 'bank': '🏦', 'post': '🏤', 'factory': '🏭', 'office': '🏢',

      // Misc
      'heart': '❤️', 'bat': '🦇', 'web': '🕸️', 'garden': '🏡', 'party': '🎉',
      'celebration': '🎊', 'birthday': '🎂', 'christmas': '🎄', 'gift': '🎁', 'present': '🎁',
      'magic': '✨', 'fairy': '🧚', 'wizard': '🧙', 'princess': '👸', 'prince': '🤴',
      'king': '🤴', 'queen': '👸', 'knight': '⚔️', 'pirate': '🏴‍☠️', 'ninja': '🥷',
      'time': '⏰', 'clock': '🕐', 'calendar': '📅', 'bell': '🔔', 'alarm': '⏰',
    };
    return wordEmojis[word.toLowerCase()] ?? '📝';
  }

  /// Create a set of falling words with one target
  static List<FallingWord> createSet({
    required List<String> words,
    required int count,
    required String targetWord,
  }) {
    final random = Random();
    final result = <FallingWord>[];

    // Shuffle and pick words
    final shuffled = List<String>.from(words)..shuffle(random);
    final selectedWords = <String>[];

    // Ensure target is included
    selectedWords.add(targetWord);

    // Add other unique words
    for (final word in shuffled) {
      if (selectedWords.length >= count) break;
      if (word != targetWord) {
        selectedWords.add(word);
      }
    }

    // Shuffle the selected words
    selectedWords.shuffle(random);

    // Create falling words with evenly distributed x positions
    for (int i = 0; i < selectedWords.length; i++) {
      final word = selectedWords[i];
      // Distribute horizontally with some padding
      final x = (i + 0.5) / selectedWords.length;

      result.add(FallingWord(
        word: word,
        emoji: getEmoji(word),
        x: x,
        y: -0.05 - (random.nextDouble() * 0.1), // Slight vertical offset
        isTarget: word == targetWord,
      ));
    }

    return result;
  }
}
