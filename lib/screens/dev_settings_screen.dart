import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/bulk_review_generator.dart';

class DevSettingsScreen extends StatefulWidget {
  const DevSettingsScreen({Key? key}) : super(key: key);

  @override
  _DevSettingsScreenState createState() => _DevSettingsScreenState();
}

class _DevSettingsScreenState extends State<DevSettingsScreen> {
  bool _isGeneratingReviews = false;
  final BulkReviewGenerator _reviewGenerator = BulkReviewGenerator();

  // List of admin emails who can access development tools
  final List<String> _adminEmails = [
    'admin@example.com',
    // Add other admin emails here
  ];

  // Configuration variables for bulk review generation
  int _numberOfMovies = 50;
  int _reviewsPerMovie = 3;

  Future<void> _generateBulkReviews() async {
    // Check if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to use this feature'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingReviews = true;
    });

    try {
      // Optional: Create mock users first
      await _reviewGenerator.createMockUsers();

      // Generate bulk reviews with current configuration
      await _reviewGenerator.generateBulkReviews(
          numberOfMovies: _numberOfMovies, reviewsPerMovie: _reviewsPerMovie);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Generated $_numberOfMovies movies with $_reviewsPerMovie reviews each'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating reviews: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingReviews = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Development Tools'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Bulk Review Generator Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bulk Review Generator',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Number of Movies Slider
                  const Text('Number of Movies'),
                  Slider(
                    value: _numberOfMovies.toDouble(),
                    min: 10,
                    max: 100,
                    divisions: 9,
                    label: _numberOfMovies.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _numberOfMovies = value.round();
                      });
                    },
                  ),

                  // Reviews per Movie Slider
                  const Text('Reviews per Movie'),
                  Slider(
                    value: _reviewsPerMovie.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: _reviewsPerMovie.round().toString(),
                    onChanged: (double value) {
                      setState(() {
                        _reviewsPerMovie = value.round();
                      });
                    },
                  ),

                  // Generate Button
                  Center(
                    child: ElevatedButton(
                      onPressed:
                          _isGeneratingReviews ? null : _generateBulkReviews,
                      child: _isGeneratingReviews
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Generate Bulk Reviews'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Additional Development Tools can be added here
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Clear All Reviews'),
              subtitle: const Text('Removes all existing diary entries'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                onPressed: () async {
                  // Implement review deletion logic
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Reviews'),
                      content:
                          const Text('Are you sure? This cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Clear',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    // TODO: Implement review deletion logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Review deletion not implemented'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
