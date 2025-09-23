// Updated lib/services/tmdb_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';

class TMDBService {
  static const String _apiKey = '4ae207526acb81363b703e810d265acf';
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';

  // Cache for popular movie titles
  static List<Map<String, dynamic>> _popularMoviesCache = [];
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(hours: 1);

  // Cache for movie directors
  static final Map<String, String> _directorCache = {};
  static final Set<String> _pendingDirectorRequests = {};

  // Cache for search results
  static final Map<String, List<Movie>> _searchCache = {};
  static final Map<String, DateTime> _searchCacheTimestamps = {};
  static const Duration _searchCacheExpiry = Duration(minutes: 30);

  // Get cached popular movies or fetch new ones if cache is expired
  static Future<List<Map<String, dynamic>>>
  getPopularMoviesForSuggestions() async {
    final now = DateTime.now();

    if (_popularMoviesCache.isNotEmpty &&
        _lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!) < _cacheExpiry) {
      return _popularMoviesCache;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _popularMoviesCache = List<Map<String, dynamic>>.from(data['results']);
        _lastCacheUpdate = now;
        return _popularMoviesCache;
      } else {
        throw Exception('Failed to load popular movies for suggestions');
      }
    } catch (e) {
      // Return cached data even if expired if available, otherwise empty list
      return _popularMoviesCache;
    }
  }

  // Get suggestions based on prefix
  static Future<List<Map<String, dynamic>>> getSuggestions(
    String prefix,
  ) async {
    if (prefix.isEmpty) return [];

    final movies = await getPopularMoviesForSuggestions();
    final lowercasePrefix = prefix.toLowerCase();

    return movies.where((movie) {
      final title = movie['title']?.toString().toLowerCase() ?? '';
      return title.startsWith(lowercasePrefix);
    }).toList();
  }

  // Get movies by genre IDs
  static Future<List<Map<String, dynamic>>> getMoviesByGenres(
    List<int> genreIds,
  ) async {
    print('Getting movies for genres: $genreIds');

    if (genreIds.isEmpty) return [];

    // Convert genre IDs to comma-separated string
    final String genreParam = genreIds.join(',');

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=$genreParam&sort_by=popularity.desc',
      ),
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
      Uri.parse('$_baseUrl/trending/movie/day?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['results']);
    } else {
      throw Exception('Failed to load trending movies');
    }
  }

  static Future<List<Map<String, dynamic>>> searchMoviesRaw(
    String query,
  ) async {
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
    String movieId,
  ) async {
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

  // Enhanced search method with caching and optimized search patterns
  Future<List<Movie>> searchMovies(String query) async {
    if (query.isEmpty) {
      return [];
    }

    // Check cache first
    final now = DateTime.now();
    final cachedResults = _searchCache[query];
    final cacheTimestamp = _searchCacheTimestamps[query];

    if (cachedResults != null &&
        cacheTimestamp != null &&
        now.difference(cacheTimestamp) < _searchCacheExpiry) {
      return cachedResults;
    }

    try {
      // Use TMDB's built-in search capabilities with optimized parameters
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search/movie?api_key=$_apiKey&query=${Uri.encodeComponent(query)}'
          '&include_adult=false&language=en-US&page=1&sort_by=popularity.desc',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        // Extract movie IDs for bulk director fetching
        final movieIds =
            results.map((movie) => movie['id'].toString()).toList();
        final directors = await _bulkFetchDirectors(movieIds);

        final movies =
            results.map((movie) {
              final posterPath = movie['poster_path'];
              final releaseDate = movie['release_date'] as String?;
              final movieId = movie['id'].toString();
              String year = '';
              String formattedReleaseDate = '';

              if (releaseDate != null && releaseDate.isNotEmpty) {
                year = releaseDate.split('-')[0];
                final date = DateTime.parse(releaseDate);
                formattedReleaseDate =
                    '${_getMonthName(date.month)} ${date.day}, ${date.year}';
              }

              return Movie(
                id: movieId,
                title: movie['title'],
                posterUrl: posterPath != null ? '$imageBaseUrl$posterPath' : '',
                year: year,
                overview: movie['overview'] ?? '',
                voteAverage: (movie['vote_average'] ?? 0.0).toDouble(),
                popularity: (movie['popularity'] ?? 0.0).toDouble(),
                releaseDate: formattedReleaseDate,
                director: directors[movieId] ?? '',
              );
            }).toList();

        // Cache the results
        _searchCache[query] = movies;
        _searchCacheTimestamps[query] = now;

        return movies;
      } else {
        throw Exception('Failed to search movies: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching movies: $e');
      return [];
    }
  }

  // Get popular movies with optimized director fetching
  Future<List<Movie>> getPopularMovies() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/movie/popular?api_key=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;

      // Extract movie IDs for bulk director fetching
      final movieIds = results.map((movie) => movie['id'].toString()).toList();
      final directors = await _bulkFetchDirectors(movieIds);

      return results.map((movie) {
        final posterPath = movie['poster_path'];
        final releaseDate = movie['release_date'] as String?;
        final movieId = movie['id'].toString();
        String year = '';

        if (releaseDate != null && releaseDate.isNotEmpty) {
          year = releaseDate.split('-')[0];
        }

        return Movie(
          id: movieId,
          title: movie['title'],
          posterUrl: posterPath != null ? '$imageBaseUrl$posterPath' : '',
          year: year,
          overview: movie['overview'] ?? '',
          popularity: (movie['popularity'] ?? 0.0).toDouble(),
          director: directors[movieId] ?? '',
        );
      }).toList();
    } else {
      throw Exception('Failed to load popular movies');
    }
  }

  // Get trending movies
  Future<List<Movie>> getTrendingMovies() async {
    final moviesData = await getTrendingMoviesRaw();
    return moviesData.map((data) => Movie.fromJson(data)).toList();
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
          .where(
            (video) => video['site'] == 'YouTube' && video['type'] == 'Trailer',
          )
          .toList();
    } else {
      throw Exception('Failed to load videos');
    }
  }

  static Future<List<Map<String, dynamic>>> getStreamingProviders(
    String movieId,
  ) async {
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
      Uri.parse(
        '$_baseUrl/search/person?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&sort_by=popularity.desc',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Filter to only include actors with profile photos and sort by popularity
      return List<Map<String, dynamic>>.from(data['results'])
          .where(
            (person) =>
                person['known_for_department'] == 'Acting' &&
                person['profile_path'] != null,
          )
          .toList();
    } else {
      throw Exception('Failed to search actors');
    }
  }

  // Fetch movie details by ID
  Future<Movie?> getMovieDetails(String movieId) async {
    // Check cache first (implement caching if desired)
    // if (_movieDetailCache.containsKey(movieId)) {
    //   return _movieDetailCache[movieId];
    // }

    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/movie/$movieId?api_key=$_apiKey&append_to_response=credits',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Extract director from credits
        String director = '';
        if (data['credits'] != null && data['credits']['crew'] != null) {
          final crew = data['credits']['crew'] as List;
          final directorData = crew.firstWhere(
            (member) => member['job'] == 'Director',
            orElse: () => null,
          );
          if (directorData != null) {
            director = directorData['name'] ?? '';
          }
        }

        // Construct the Movie object
        final movie = Movie.fromJson({...data, 'director': director});

        // Cache the result (implement caching if desired)
        // _movieDetailCache[movieId] = movie;

        return movie;
      } else {
        print(
          'Failed to load movie details for ID $movieId: ${response.statusCode}',
        );
        return null;
      }
    } catch (e) {
      print('Error fetching movie details for ID $movieId: $e');
      return null;
    }
  }

  // Bulk fetch directors for a list of movie IDs
  static Future<Map<String, String>> _bulkFetchDirectors(
    List<String> movieIds,
  ) async {
    final Map<String, String> directors = {};
    final List<String> uncachedIds = [];

    // Check cache first
    for (final id in movieIds) {
      if (_directorCache.containsKey(id)) {
        directors[id] = _directorCache[id]!;
      } else if (!_pendingDirectorRequests.contains(id)) {
        uncachedIds.add(id);
        _pendingDirectorRequests.add(id);
      }
    }

    if (uncachedIds.isEmpty) {
      return directors;
    }

    // Process uncached IDs in batches of 5
    for (var i = 0; i < uncachedIds.length; i += 5) {
      final batch = uncachedIds.skip(i).take(5).toList();
      final futures = batch.map((id) => _fetchDirectorForMovie(id));

      try {
        final results = await Future.wait(futures);
        for (var j = 0; j < batch.length; j++) {
          final id = batch[j];
          final director = results[j];
          directors[id] = director;
          _directorCache[id] = director;
          _pendingDirectorRequests.remove(id);
        }
      } catch (e) {
        print('Error fetching directors for batch: $e');
        // Clear pending requests for failed batch
        for (final id in batch) {
          _pendingDirectorRequests.remove(id);
        }
      }
    }

    return directors;
  }

  // Fetch director for a single movie
  static Future<String> _fetchDirectorForMovie(String movieId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/movie/$movieId/credits?api_key=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final crew = data['crew'] as List;
        final directorInfo = crew.firstWhere(
          (member) => member['job'] == 'Director',
          orElse: () => {'name': ''},
        );
        return directorInfo['name'] ?? '';
      }
    } catch (e) {
      print('Error fetching director for movie $movieId: $e');
    }
    return '';
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
