class Movie {
  final String id;
  final String title;
  final String posterUrl;
  final String year;
  final String overview;
  final double rating;

  Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.year,
    required this.overview,
    this.rating = 0.0,
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

    // Extract rating (vote_average from TMDB)
    final rating = json['vote_average'] != null
        ? (json['vote_average'] is int
            ? (json['vote_average'] as int).toDouble()
            : json['vote_average'] as double)
        : 0.0;

    return Movie(
      id: movieId,
      title: json['title'] ?? json['name'] ?? '',
      posterUrl: posterUrl,
      year: year,
      overview: json['overview'] ?? '',
      rating: rating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'year': year,
      'overview': overview,
      'rating': rating,
    };
  }
}
