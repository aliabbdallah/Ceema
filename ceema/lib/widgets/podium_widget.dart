import 'package:flutter/material.dart';
import '../models/podium_movie.dart';

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

  @override
  Widget build(BuildContext context) {
    // Sort movies by rank
    final sortedMovies = List<PodiumMovie>.from(movies)
      ..sort((a, b) => a.rank.compareTo(b.rank));

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
                    height: 190,
                    width: 124,
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
                    height: 210,
                    width: 134,
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
                    height: 180,
                    width: 124,
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
      onTap: () => onMovieTap?.call(movie),
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
          const SizedBox(height: 12),
          // Movie title
          SizedBox(
            width: width,
            child: Text(
              movie.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (movie.comment != null && movie.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Movie comment
            SizedBox(
              width: width,
              child: Text(
                movie.comment!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
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
