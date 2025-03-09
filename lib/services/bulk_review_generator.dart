import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/movie.dart';
import '../services/tmdb_service.dart';
import 'dart:math';

class BulkReviewGenerator {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // Generate a list of fictional user IDs
  final List<String> _userIds = [
    'user1',
    'user2',
    'user3',
    'user4',
    'user5',
    'user6',
    'user7',
    'user8',
    'user9',
    'user10'
  ];

  // Predefined user names and avatars
  final List<Map<String, String>> _users = [
    {
      'name': 'Movie Lover',
      'avatar':
          'https://ui-avatars.com/api/?name=MovieLover&background=0D8ABC&color=fff'
    },
    {
      'name': 'Cinema Fan',
      'avatar':
          'https://ui-avatars.com/api/?name=CinemaFan&background=FFC107&color=fff'
    },
    {
      'name': 'Film Critic',
      'avatar':
          'https://ui-avatars.com/api/?name=FilmCritic&background=4CAF50&color=fff'
    },
    {
      'name': 'Blockbuster Buff',
      'avatar':
          'https://ui-avatars.com/api/?name=BlockbusterBuff&background=FF5722&color=fff'
    },
    {
      'name': 'Indie Watcher',
      'avatar':
          'https://ui-avatars.com/api/?name=IndieWatcher&background=9C27B0&color=fff'
    },
    {
      'name': 'Sci-Fi Enthusiast',
      'avatar':
          'https://ui-avatars.com/api/?name=SciFiEnthusiast&background=2196F3&color=fff'
    },
    {
      'name': 'Drama Queen',
      'avatar':
          'https://ui-avatars.com/api/?name=DramaQueen&background=E91E63&color=fff'
    },
    {
      'name': 'Comedy King',
      'avatar':
          'https://ui-avatars.com/api/?name=ComedyKing&background=FF9800&color=fff'
    },
    {
      'name': 'Action Hero',
      'avatar':
          'https://ui-avatars.com/api/?name=ActionHero&background=795548&color=fff'
    },
    {
      'name': 'Horror Fan',
      'avatar':
          'https://ui-avatars.com/api/?name=HorrorFan&background=607D8B&color=fff'
    }
  ];

  // Predefined review templates
  final List<String> _reviewTemplates = [
    'Amazing movie! Totally recommend.',
    'Not what I expected, but still enjoyable.',
    'A masterpiece of modern cinema.',
    'Waste of time, wouldn\'t watch again.',
    'Interesting plot, great performances.',
    'Absolutely loved the cinematography.',
    'A bit slow, but had some great moments.',
    'Exceeded all my expectations!',
    'Typical genre film, nothing special.',
    'A hidden gem that deserves more attention.'
  ];

  // Generate bulk reviews for multiple movies
  Future<void> generateBulkReviews({
    int numberOfMovies = 50,
    int reviewsPerMovie = 3,
  }) async {
    try {
      // Fetch trending movies
      final moviesData = await TMDBService.getTrendingMovies();

      // Limit to specified number of movies
      final movies = moviesData
          .take(numberOfMovies)
          .map((data) => Movie.fromJson(data))
          .toList();

      // Generate reviews for each movie
      for (var movie in movies) {
        await _generateReviewsForMovie(movie, reviewsPerMovie);
      }

      print('Bulk reviews generation completed!');
    } catch (e) {
      print('Error generating bulk reviews: $e');
    }
  }

  Future<void> _generateReviewsForMovie(
      Movie movie, int numberOfReviews) async {
    for (int i = 0; i < numberOfReviews; i++) {
      // Randomly select a user
      final userIndex = _random.nextInt(_users.length);
      final user = _users[userIndex];

      // Create a diary entry
      await _firestore.collection('diary_entries').add({
        'userId': _userIds[userIndex],
        'movieId': movie.id,
        'movieTitle': movie.title,
        'moviePosterUrl': movie.posterUrl,
        'movieYear': movie.year,

        // Random rating between 1 and 5
        'rating': (_random.nextDouble() * 4 + 1).roundToDouble(),

        // Random review from templates
        'review': _reviewTemplates[_random.nextInt(_reviewTemplates.length)],

        // Random watched date in the last 6 months
        'watchedDate': Timestamp.fromDate(
          DateTime.now().subtract(
            Duration(days: _random.nextInt(180)),
          ),
        ),

        // Random flags
        'isFavorite': _random.nextBool(),
        'isRewatch': _random.nextBool(),

        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Create mock user accounts in Firestore
  Future<void> createMockUsers() async {
    for (int i = 0; i < _users.length; i++) {
      await _firestore.collection('users').doc(_userIds[i]).set({
        'username': _users[i]['name'],
        'email': '${_userIds[i]}@example.com',
        'profileImageUrl': _users[i]['avatar'],
        'createdAt': FieldValue.serverTimestamp(),
        'favoriteGenres': [], // You can populate this if needed
        'followersCount': 0,
        'followingCount': 0,
        'emailVerified': true,
      });
    }
  }
}

// Example usage
void main() async {
  // Initialize Firebase first in your app
  // await Firebase.initializeApp();

  final generator = BulkReviewGenerator();

  // Optional: Create mock users first
  await generator.createMockUsers();

  // Generate bulk reviews
  await generator.generateBulkReviews(
      numberOfMovies: 50, // Number of movies to generate reviews for
      reviewsPerMovie: 3 // Number of reviews per movie
      );
}
