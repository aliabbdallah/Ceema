class Movie {
  final String id;
  final String title;
  final String posterUrl;
  final String year;
  final String overview;
  final double voteAverage;
  final double popularity;

  Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.year,
    required this.overview,
    this.voteAverage = 0.0,
    this.popularity = 0.0,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    // Convert the integer id to string
    final movieId = json['id']?.toString() ?? '';

    // Extract year from release_date
    String year = '';
    if (json['release_date'] != null &&
        json['release_date'].toString().isNotEmpty) {
      year = json['release_date'].toString().substring(0, 4);
    }

    // Construct full poster URL
    final posterPath = json['poster_path'];
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : 'https://via.placeholder.com/500x750.png?text=No+Poster';

    // Extract vote average from TMDB
    final voteAverage = json['vote_average'] != null
        ? (json['vote_average'] is int
            ? (json['vote_average'] as int).toDouble()
            : json['vote_average'] as double)
        : 0.0;

    // Extract popularity from TMDB
    final popularity = json['popularity'] != null
        ? (json['popularity'] is int
            ? (json['popularity'] as int).toDouble()
            : json['popularity'] as double)
        : 0.0;

    return Movie(
      id: movieId,
      title: json['title'] ?? json['name'] ?? '',
      posterUrl: posterUrl,
      year: year,
      overview: json['overview'] ?? '',
      voteAverage: voteAverage,
      popularity: popularity,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'year': year,
      'overview': overview,
      'voteAverage': voteAverage,
      'popularity': popularity,
    };
  }
}
