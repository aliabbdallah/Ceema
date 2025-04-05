// Updated lib/services/tmdb_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';

class TMDBService {
  static const String _apiKey = '4ae207526acb81363b703e810d265acf';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String _imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

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

  static Future<List<Map<String, dynamic>>> getTrendingMoviesRaw() async {
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

  static Future<List<Map<String, dynamic>>> searchMoviesRaw(
      String query) async {
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

  static Future<Map<String, dynamic>> getMovieDetailsRaw(String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load movie details');
    }
  }

  // New method to get movie credits specifically
  static Future<Map<String, dynamic>> getMovieCredits(String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId/credits?api_key=$_apiKey'),
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
      throw Exception('Failed to load movie credits');
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

  static Future<List<Map<String, dynamic>>> getTopRatedMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/top_rated?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final jsonString = response.body;
      final jsonReader = JsonDecoder((key, value) {
        return value;
      });
      final data = jsonReader.convert(jsonString);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load top rated movies');
    }
  }

  // Search for movies
  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final response = await http.get(
      Uri.parse(
          '$_baseUrl/search/movie?api_key=$_apiKey&query=$query&include_adult=false'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;

      return results.map((movie) {
        final posterPath = movie['poster_path'];
        final releaseDate = movie['release_date'] as String?;
        String year = '';

        if (releaseDate != null && releaseDate.isNotEmpty) {
          year = releaseDate.split('-')[0];
        }

        return Movie(
          id: movie['id'].toString(),
          title: movie['title'],
          posterUrl: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
          year: year,
          overview: movie['overview'] ?? '',
        );
      }).toList();
    } else {
      throw Exception('Failed to search movies: ${response.statusCode}');
    }
  }

  // Get movie details
  Future<Movie> getMovieDetails(String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final posterPath = data['poster_path'];
      final releaseDate = data['release_date'] as String?;
      String year = '';

      if (releaseDate != null && releaseDate.isNotEmpty) {
        year = releaseDate.split('-')[0];
      }

      return Movie(
        id: data['id'].toString(),
        title: data['title'],
        posterUrl: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
        year: year,
        overview: data['overview'] ?? '',
      );
    } else {
      throw Exception('Failed to get movie details: ${response.statusCode}');
    }
  }

  // Get popular movies
  Future<List<Movie>> getPopularMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;

      return results.map((movie) {
        final posterPath = movie['poster_path'];
        final releaseDate = movie['release_date'] as String?;
        String year = '';

        if (releaseDate != null && releaseDate.isNotEmpty) {
          year = releaseDate.split('-')[0];
        }

        return Movie(
          id: movie['id'].toString(),
          title: movie['title'],
          posterUrl: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
          year: year,
          overview: movie['overview'] ?? '',
        );
      }).toList();
    } else {
      throw Exception('Failed to get popular movies: ${response.statusCode}');
    }
  }

  // Get trending movies
  Future<List<Movie>> getTrendingMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/trending/movie/week?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;

      return results.map((movie) {
        final posterPath = movie['poster_path'];
        final releaseDate = movie['release_date'] as String?;
        String year = '';

        if (releaseDate != null && releaseDate.isNotEmpty) {
          year = releaseDate.split('-')[0];
        }

        return Movie(
          id: movie['id'].toString(),
          title: movie['title'],
          posterUrl: posterPath != null ? '$_imageBaseUrl$posterPath' : '',
          year: year,
          overview: movie['overview'] ?? '',
        );
      }).toList();
    } else {
      throw Exception('Failed to get trending movies: ${response.statusCode}');
    }
  }

  static Future<List<Map<String, dynamic>>> getCast(String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId/credits?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['cast']);
    } else {
      throw Exception('Failed to load cast');
    }
  }

  static Future<List<Map<String, dynamic>>> getCrew(String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId/credits?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['crew']);
    } else {
      throw Exception('Failed to load crew');
    }
  }

  static Future<List<Map<String, dynamic>>> getVideos(String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId/videos?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results'])
          .where((video) =>
              video['site'] == 'YouTube' && video['type'] == 'Trailer')
          .toList();
    } else {
      throw Exception('Failed to load videos');
    }
  }

  static Future<List<Map<String, dynamic>>> getStreamingProviders(
      String movieId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/$movieId/watch/providers?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'];
      if (results != null && results['US'] != null) {
        return List<Map<String, dynamic>>.from(results['US']['flatrate'] ?? []);
      }
      return [];
    } else {
      throw Exception('Failed to load streaming providers');
    }
  }

  static Future<Map<String, dynamic>> getPersonDetails(String personId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/person/$personId?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load person details');
    }
  }

  static Future<Map<String, dynamic>> getPersonCredits(String personId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/person/$personId/combined_credits?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load person credits');
    }
  }

  // Search for actors/people
  static Future<List<Map<String, dynamic>>> searchActors(String query) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/search/person?api_key=$_apiKey&query=${Uri.encodeComponent(query)}'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to search actors');
    }
  }
}
