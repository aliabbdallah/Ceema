class Mood {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final List<int> genreIds;
  final String color;

  Mood({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.genreIds,
    required this.color,
  });

  factory Mood.fromJson(Map<String, dynamic> json) {
    return Mood(
      id: json['id'],
      name: json['name'],
      emoji: json['emoji'],
      description: json['description'],
      genreIds: List<int>.from(json['genreIds']),
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'description': description,
      'genreIds': genreIds,
      'color': color,
    };
  }
}

// Predefined moods with corresponding genre IDs from TMDB
// TMDB Genre IDs:
// 28: Action, 12: Adventure, 16: Animation, 35: Comedy, 80: Crime, 99: Documentary,
// 18: Drama, 10751: Family, 14: Fantasy, 36: History, 27: Horror, 10402: Music,
// 9648: Mystery, 10749: Romance, 878: Science Fiction, 10770: TV Movie, 53: Thriller,
// 10752: War, 37: Western
class MoodData {
  static List<Mood> getMoods() {
    return [
      Mood(
        id: 'happy',
        name: 'Happy',
        emoji: '😊',
        description: 'Uplifting and joyful movies to boost your mood',
        genreIds: [35, 10751, 16, 10402], // Comedy, Family, Animation, Music
        color: '#FFD700', // Gold
      ),
      Mood(
        id: 'sad',
        name: 'Sad',
        emoji: '😢',
        description: 'Emotional and touching stories that resonate with your feelings',
        genreIds: [18, 10749], // Drama, Romance
        color: '#4169E1', // Royal Blue
      ),
      Mood(
        id: 'excited',
        name: 'Excited',
        emoji: '🤩',
        description: 'Thrilling and action-packed adventures to get your heart racing',
        genreIds: [28, 12, 878], // Action, Adventure, Science Fiction
        color: '#FF4500', // Orange Red
      ),
      Mood(
        id: 'relaxed',
        name: 'Relaxed',
        emoji: '😌',
        description: 'Calm and soothing films for a peaceful viewing experience',
        genreIds: [99, 36, 10770], // Documentary, History, TV Movie
        color: '#20B2AA', // Light Sea Green
      ),
      Mood(
        id: 'scared',
        name: 'Scared',
        emoji: '😱',
        description: 'Spine-chilling horror and suspense to embrace your fears',
        genreIds: [27, 53, 9648], // Horror, Thriller, Mystery
        color: '#800080', // Purple
      ),
      Mood(
        id: 'romantic',
        name: 'Romantic',
        emoji: '❤️',
        description: 'Love stories and heartwarming tales to make you feel the love',
        genreIds: [10749, 18], // Romance, Drama
        color: '#FF69B4', // Hot Pink
      ),
      Mood(
        id: 'thoughtful',
        name: 'Thoughtful',
        emoji: '🤔',
        description: 'Thought-provoking and intellectually stimulating films',
        genreIds: [9648, 878, 18], // Mystery, Science Fiction, Drama
        color: '#483D8B', // Dark Slate Blue
      ),
      Mood(
        id: 'nostalgic',
        name: 'Nostalgic',
        emoji: '🕰️',
        description: 'Classic and timeless movies to take you back in time',
        genreIds: [36, 37, 10752], // History, Western, War
        color: '#8B4513', // Saddle Brown
      ),
    ];
  }

  static Mood getMoodById(String id) {
    return getMoods().firstWhere(
      (mood) => mood.id == id,
      orElse: () => getMoods()[0],
    );
  }
}
