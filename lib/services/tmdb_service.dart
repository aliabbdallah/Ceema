// services/tmdb_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class TMDBService {
  static const String _apiKey = '4ae207526acb81363b703e810d265acf';
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  static Future<List<Map<String, dynamic>>> getTrendingMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/movie/week?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
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
      final data = json.decode(response.body);
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
      return json.decode(response.body);
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
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load similar movies');
    }
  }
}
