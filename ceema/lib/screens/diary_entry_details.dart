// screens/diary_entry_details.dart
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../models/movie.dart';
import 'diary_entry_form.dart';
import '../services/diary_service.dart';

class DiaryEntryDetails extends StatelessWidget {
  final DiaryEntry entry;
  final DiaryService _diaryService = DiaryService();

  DiaryEntryDetails({
    Key? key,
    required this.entry,
  }) : super(key: key);

  Future<void> _deleteEntry(BuildContext context) async {
    final bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content:
            const Text('Are you sure you want to delete this diary entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _diaryService.deleteDiaryEntry(entry.id);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Entry deleted'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting entry: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = Movie(
      id: entry.movieId,
      title: entry.movieTitle,
      posterUrl: entry.moviePosterUrl,
      year: entry.movieYear,
      overview: '', // We might want to fetch this from the API
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diary Entry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiaryEntryForm(
                    movie: movie,
                    existingEntry: entry,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteEntry(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        entry.moviePosterUrl,
                        width: 120,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.movieTitle,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            entry.movieYear,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ...List.generate(5, (index) {
                                return Icon(
                                  index < entry.rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                  size: 24,
                                );
                              }),
                              const SizedBox(width: 8),
                              Text(
                                entry.rating.toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Watch info
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Watched on'),
                    subtitle: Text(
                      entry.watchedDate.toString().split(' ')[0],
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  if (entry.isRewatch)
                    const ListTile(
                      leading: Icon(Icons.replay),
                      title: Text('Rewatch'),
                    ),
                  if (entry.isFavorite)
                    const ListTile(
                      leading: Icon(Icons.favorite, color: Colors.red),
                      title: Text('Added to favorites'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Review
            if (entry.review.isNotEmpty) ...[
              const Text(
                'Your Review',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    entry.review,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
