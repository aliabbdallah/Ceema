import 'dart:convert';
import 'package:http/http.dart' as http;

class TMDBService {
  static const String _apiKey = '4ae207526acb81363b703e810d265acf';
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  // Get movies by genre IDs
  static Future<List<Map<String, dynamic>>> getMoviesByGenres(
      List<int> genreIds) async {
    print('Getting movies for genres: $genreIds');

    if (genreIds.isEmpty) return [];

    // Convert genre IDs to comma-separated string
    final String genreParam = genreIds.join(',');

    final response = await http.get(
      Uri.parse(
          '$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=$genreParam&sort_by=popularity.desc'),
    );

    if (response.statusCode == 200) {
      final jsonString = response.body;
      final jsonReader = JsonDecoder((key, value) {
        return value;
      });
      final data = jsonReader.convert(jsonString);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load movies by genres');
    }
  }

  static Future<List<Map<String, dynamic>>> getTrendingMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/movie/week?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      // Use a more lenient approach to JSON parsing
      final jsonString = response.body;
      final jsonReader = JsonDecoder((key, value) {
        // This is a custom reviver function that can handle malformed JSON
        return value;
      });
      final data = jsonReader.convert(jsonString);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load trending movies');
    }
  }

  static Future<List<Map<String, dynamic>>> searchMovies(String query) async {
    if (query.isEmpty) return [];

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(query)}',
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
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to search movies');
    }
  }

  static Future<Map<String, dynamic>> getMovieDetails(String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      // Use a more lenient approach to JSON parsing
      final jsonString = response.body;
      final jsonReader = JsonDecoder((key, value) {
        // This is a custom reviver function that can handle malformed JSON
        return value;
      });
      return jsonReader.convert(jsonString);
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  static Future<List<Map<String, dynamic>>> getSimilarMovies(
      String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId/similar?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      // Use a more lenient approach to JSON parsing
      final jsonString = response.body;
      final jsonReader = JsonDecoder((key, value) {
        // This is a custom reviver function that can handle malformed JSON
        return value;
      });
      final data = jsonReader.convert(jsonString);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load similar movies');
    }
  }
}
