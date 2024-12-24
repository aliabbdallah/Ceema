class Movie {
  final String id;
  final String title;
  final String posterUrl;
  final String year;
  final String overview;

  Movie({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.year,
    required this.overview,
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

    return Movie(
      id: movieId,
      title: json['title'] ?? json['name'] ?? '',
      posterUrl: posterUrl,
      year: year,
      overview: json['overview'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'year': year,
      'overview': overview,
    };
  }
}
