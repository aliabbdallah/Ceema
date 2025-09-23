import 'package:flutter/material.dart';
import '../models/podium_movie.dart';
import '../models/movie.dart';
import '../screens/movie_details_screen.dart';

class PodiumWidget extends StatelessWidget {
  final List<PodiumMovie> movies;
  final bool isEditable;
  final Function(PodiumMovie)? onMovieTap;
  final Function(int)? onRankTap;
  final Function(int, int)? onRankSwap;

  const PodiumWidget({
    Key? key,
    required this.movies,
    this.isEditable = false,
    this.onMovieTap,
    this.onRankTap,
    this.onRankSwap,
  }) : super(key: key);

  void _handleMovieTap(BuildContext context, PodiumMovie movie) {
    if (onMovieTap != null) {
      onMovieTap!(movie);
    } else {
      // Convert PodiumMovie to Movie and navigate to details screen
      final movieDetails = Movie(
        id: movie.tmdbId,
        title: movie.title,
        posterUrl: movie.posterUrl,
        year: '', // Not available in PodiumMovie
        overview: '', // Not available in PodiumMovie
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MovieDetailsScreen(movie: movieDetails),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort movies by rank
    final sortedMovies = List<PodiumMovie>.from(movies)
      ..sort((a, b) => a.rank.compareTo(b.rank));

    // Calculate responsive dimensions based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final podiumWidth = screenWidth * 0.28; // 28% of screen width
    final podiumHeight = podiumWidth * 1.5; // Maintain aspect ratio

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Second place (silver)
              if (sortedMovies.length >= 2)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: _buildPodiumStep(
                    context,
                    sortedMovies[1],
                    height: podiumHeight * 0.9, // 90% of first place height
                    width: podiumWidth * 0.9, // 90% of first place width
                    color: Colors.grey[300]!,
                    rank: 2,
                    medalColor: Colors.grey[400]!,
                  ),
                ),
              // First place (gold)
              if (sortedMovies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildPodiumStep(
                    context,
                    sortedMovies[0],
                    height: podiumHeight,
                    width: podiumWidth,
                    color: Colors.amber,
                    rank: 1,
                    medalColor: Colors.amber[700]!,
                  ),
                ),
              // Third place (bronze)
              if (sortedMovies.length >= 3)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: _buildPodiumStep(
                    context,
                    sortedMovies[2],
                    height: podiumHeight * 0.85, // 85% of first place height
                    width: podiumWidth * 0.9, // 90% of first place width
                    color: Colors.brown[300]!,
                    rank: 3,
                    medalColor: Colors.brown[400]!,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumStep(
    BuildContext context,
    PodiumMovie movie, {
    required double height,
    required double width,
    required Color color,
    required int rank,
    required Color medalColor,
  }) {
    // Define border colors based on rank
    final borderColor =
        rank == 1
            ? const Color(0xFFFFD700) // Gold
            : rank == 2
            ? const Color(0xFFC0C0C0) // Silver
            : const Color(0xFFCD7F32); // Bronze

    return GestureDetector(
      onTap: () => _handleMovieTap(context, movie),
      child: Column(
        children: [
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border.all(color: borderColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Movie poster
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(9),
                    topRight: Radius.circular(9),
                  ),
                  child: Image.network(
                    movie.posterUrl,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.movie, size: 40),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Movie title
          SizedBox(
            width: width,
            child: Text(
              movie.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: width * 0.1, // Responsive font size
              ),
            ),
          ),
          if (movie.comment != null && movie.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            // Movie comment
            SizedBox(
              width: width,
              child: Text(
                movie.comment!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: width * 0.08, // Responsive font size
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
