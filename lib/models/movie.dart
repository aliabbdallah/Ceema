class Movie {
  final String id;
  final String title;
  final String posterUrl;
  final String year;
  final String overview;
  final double voteAverage;
  final double popularity;
  final String releaseDate;
  final String director;

  Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.year,
    required this.overview,
    this.voteAverage = 0.0,
    this.popularity = 0.0,
    this.releaseDate = '',
    this.director = '',
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    // Convert the integer id to string
    final movieId = json['id']?.toString() ?? '';

    // Extract year from release_date
    String year = '';
    String formattedReleaseDate = '';
    if (json['release_date'] != null &&
        json['release_date'].toString().isNotEmpty) {
      year = json['release_date'].toString().substring(0, 4);
      final date = DateTime.parse(json['release_date']);
      formattedReleaseDate =
          '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }

    // Construct full poster URL
    final posterPath = json['poster_path'];
    final posterUrl =
        posterPath != null
            ? 'https://image.tmdb.org/t/p/w500$posterPath'
            : 'https://via.placeholder.com/500x750.png?text=No+Poster';

    // Extract vote average from TMDB
    final voteAverage =
        json['vote_average'] != null
            ? (json['vote_average'] is int
                ? (json['vote_average'] as int).toDouble()
                : json['vote_average'] as double)
            : 0.0;

    // Extract popularity from TMDB
    final popularity =
        json['popularity'] != null
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
      releaseDate: formattedReleaseDate,
      director: json['director'] ?? '',
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
      'releaseDate': releaseDate,
      'director': director,
    };
  }

  static String _getMonthName(int month) {
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
