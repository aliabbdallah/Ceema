import 'package:flutter/material.dart';
import '../../../models/movie.dart';
import '../../../screens/movie_details_screen.dart';

class MovieListItem extends StatelessWidget {
  final Movie movie;

  const MovieListItem({Key? key, required this.movie}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MovieDetailsScreen(movie: movie),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Movie poster with shimmer effect
              Hero(
                tag: 'movie_poster_${movie.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      movie.posterUrl.isNotEmpty
                          ? Image.network(
                            movie.posterUrl,
                            width: 100,
                            height: 150,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 100,
                                height: 150,
                                color: colorScheme.surfaceVariant,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 150,
                                color: colorScheme.surfaceVariant,
                                child: Icon(
                                  Icons.movie,
                                  size: 50,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          )
                          : Container(
                            width: 100,
                            height: 150,
                            color: colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.movie,
                              size: 50,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                ),
              ),

              const SizedBox(width: 16),

              // Movie details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Movie title with year
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            movie.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withOpacity(
                              0.2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            movie.year,
                            style: TextStyle(
                              color: colorScheme.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Director and rating
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            movie.director.isNotEmpty
                                ? movie.director
                                : "Unknown",
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${movie.voteAverage.toStringAsFixed(1)}/10',
                          style: TextStyle(
                            color: colorScheme.secondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Empty space where overview would be
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
