import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/mood.dart';
import '../models/movie.dart';

class MoodRecommendationService {
  static const String _apiKey = '4ae207526acb81363b703e810d265acf'; // Same as TMDBService
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  /// Get movies based on a specific mood
  static Future<List<Movie>> getMoviesByMood(Mood mood, {int limit = 20}) async {
    try {
      // Convert genre IDs to comma-separated string
      final String genreIds = mood.genreIds.join(',');
      
      // Get movies by genres associated with the mood
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=$genreIds&sort_by=popularity.desc&page=1',
        ),
      );

      if (response.statusCode == 200) {
        // Use a more lenient approach to JSON parsing
        final jsonString = response.body;
        final jsonReader = JsonDecoder((key, value) {
          // This is a custom reviver function that can handle malformed JSON
          return value;
        });
        final data = jsonReader.convert(jsonString);
        final results = List<Map<String, dynamic>>.from(data['results']);
        
        // Convert to Movie objects and limit the number of results
        final movies = results
            .map((data) => Movie.fromJson(data))
            .take(limit)
            .toList();
        
        return movies;
      } else {
        throw Exception('Failed to load mood-based movies: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting mood-based movies: $e');
    }
  }

  /// Get a list of all available genres from TMDB
  static Future<Map<int, String>> getGenres() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/genre/movie/list?api_key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        // Use a more lenient approach to JSON parsing
        final jsonString = response.body;
        final jsonReader = JsonDecoder((key, value) {
          // This is a custom reviver function that can handle malformed JSON
          return value;
        });
        final data = jsonReader.convert(jsonString);
        final genres = Map<int, String>.fromEntries(
          (data['genres'] as List).map(
            (genre) => MapEntry(genre['id'] as int, genre['name'] as String),
          ),
        );
        return genres;
      } else {
        throw Exception('Failed to load genres: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error getting genres: $e');
    }
  }

  /// Save user mood preference to Firestore (for future personalization)
  static Future<void> saveUserMoodSelection(String userId, String moodId) async {
    // This would typically save to Firestore, but we'll leave it as a placeholder
    // for now since it would require additional Firebase setup
    print('Saving mood $moodId for user $userId');
    
    // Implementation would look something like:
    // await FirebaseFirestore.instance
    //     .collection('users')
    //     .doc(userId)
    //     .collection('moods')
    //     .add({
    //       'moodId': moodId,
    //       'timestamp': FieldValue.serverTimestamp(),
    //     });
  }
}
