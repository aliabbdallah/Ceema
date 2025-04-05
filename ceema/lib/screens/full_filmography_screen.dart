import 'package:flutter/material.dart';
import '../models/movie.dart';
import 'movie_details_screen.dart';

class FullFilmographyScreen extends StatelessWidget {
  final List<Map<String, dynamic>> credits;
  final String actorName;
  final Set<String> userWatchlist;
  final Set<String> userDiary;

  const FullFilmographyScreen({
    Key? key,
    required this.credits,
    required this.actorName,
    required this.userWatchlist,
    required this.userDiary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$actorName - Filmography'),
      ),
      body: Container(
        color: Colors.black87,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.667,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: credits.length,
          itemBuilder: (context, index) {
            final credit = credits[index];
            final movie = Movie.fromJson(credit);
            final movieId = movie.id;
            final isInWatchlist = userWatchlist.contains(movieId);
            final isInDiary = userDiary.contains(movieId);

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MovieDetailsScreen(movie: movie),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        movie.posterUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.movie,
                                color: Colors.white54,
                                size: 32,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (isInWatchlist || isInDiary)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            isInDiary ? Icons.check : Icons.bookmark,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
} 