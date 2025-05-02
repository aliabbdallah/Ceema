// screens/diary_entry_form.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/movie.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';

class DiaryEntryForm extends StatefulWidget {
  final Movie movie;
  final DiaryEntry? existingEntry; // Optional, for editing existing entries

  const DiaryEntryForm({Key? key, required this.movie, this.existingEntry})
    : super(key: key);

  @override
  _DiaryEntryFormState createState() => _DiaryEntryFormState();
}

class _DiaryEntryFormState extends State<DiaryEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _reviewController = TextEditingController();
  final _diaryService = DiaryService();
  final _auth = FirebaseAuth.instance;

  late DateTime _watchedDate;
  double _rating = 0;
  bool _isFavorite = false;
  bool _isRewatch = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      // Pre-fill form with existing entry data
      _watchedDate = widget.existingEntry!.watchedDate;
      _rating = widget.existingEntry!.rating;
      _isFavorite = widget.existingEntry!.isFavorite;
      _isRewatch = widget.existingEntry!.isRewatch;
      _reviewController.text = widget.existingEntry!.review;
    } else {
      _watchedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _watchedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _watchedDate) {
      setState(() {
        _watchedDate = picked;
      });
    }
  }

  String _getRatingDescription(double rating) {
    if (rating == 5.0) return 'Masterpiece!';
    if (rating >= 4.5) return 'Exceptional!';
    if (rating >= 4.0) return 'Loved it!';
    if (rating >= 3.5) return 'Really good!';
    if (rating >= 3.0) return 'Liked it';
    if (rating >= 2.5) return 'Decent';
    if (rating >= 2.0) return 'It was OK';
    if (rating >= 1.5) return 'Mediocre';
    if (rating >= 1.0) return 'Not for me';
    if (rating >= 0.5) return 'Poor';
    return '';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green[800]!;
    if (rating >= 4.0) return Colors.green;
    if (rating >= 3.5) return Colors.green[300]!;
    if (rating >= 3.0) return Colors.blue;
    if (rating >= 2.5) return Colors.blue[300]!;
    if (rating >= 2.0) return Colors.orange;
    if (rating >= 1.5) return Colors.orange[300]!;
    return Colors.red[700]!;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.existingEntry != null) {
        // Update existing entry
        await _diaryService.updateDiaryEntry(
          widget.existingEntry!.id,
          rating: _rating,
          review: _reviewController.text.trim(),
          watchedDate: _watchedDate,
          isFavorite: _isFavorite,
          isRewatch: _isRewatch,
        );
      } else {
        // Create new entry
        await _diaryService.addDiaryEntry(
          userId: _auth.currentUser!.uid,
          movie: widget.movie,
          rating: _rating,
          review: _reviewController.text.trim(),
          watchedDate: _watchedDate,
          isFavorite: _isFavorite,
          isRewatch: _isRewatch,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingEntry != null
                  ? 'Diary entry updated!'
                  : 'Movie added to diary!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRatingSelector() {
    return Column(
      children: [
        RatingBar.builder(
          initialRating: _rating,
          minRating: 0,
          direction: Axis.horizontal,
          allowHalfRating: true,
          itemCount: 5,
          itemSize: 40,
          itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          itemBuilder:
              (context, _) => const Icon(Icons.star, color: Colors.amber),
          onRatingUpdate: (rating) {
            setState(() {
              _rating = rating;
            });
          },
        ),
        const SizedBox(height: 12),
        if (_rating > 0)
          Text(
            _getRatingDescription(_rating),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _getRatingColor(_rating),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingEntry != null ? 'Edit Diary Entry' : 'Add to Diary',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Movie info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.movie.posterUrl,
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.movie.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.movie.year,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Rating
              const Text(
                'Your Rating',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildRatingSelector(),
              const SizedBox(height: 24),

              // Watch date
              ListTile(
                title: const Text('Watch Date'),
                subtitle: Text(DateFormat('MMMM d, yyyy').format(_watchedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 16),

              // Review
              TextFormField(
                controller: _reviewController,
                decoration: InputDecoration(
                  labelText: 'Review (Optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 5,
                maxLength: 500,
              ),
              const SizedBox(height: 16),

              // Additional options
              SwitchListTile(
                title: const Text('Mark as Favorite'),
                value: _isFavorite,
                onChanged: (value) {
                  setState(() {
                    _isFavorite = value;
                  });
                },
                secondary: const Icon(Icons.favorite),
              ),
              SwitchListTile(
                title: const Text('Rewatch'),
                value: _isRewatch,
                onChanged: (value) {
                  setState(() {
                    _isRewatch = value;
                  });
                },
                secondary: const Icon(Icons.replay),
              ),
              const SizedBox(height: 24),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : Text(
                          widget.existingEntry != null
                              ? 'Update Entry'
                              : 'Add to Diary',
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
