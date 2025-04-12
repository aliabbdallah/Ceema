import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';

class EditDiaryEntryScreen extends StatefulWidget {
  final DiaryEntry entry;

  const EditDiaryEntryScreen({Key? key, required this.entry}) : super(key: key);

  @override
  State<EditDiaryEntryScreen> createState() => _EditDiaryEntryScreenState();
}

class _EditDiaryEntryScreenState extends State<EditDiaryEntryScreen> {
  late TextEditingController _reviewController;
  late double _rating;
  late DateTime _watchedDate;
  late bool _isFavorite;
  late bool _isRewatch;

  @override
  void initState() {
    super.initState();
    _reviewController = TextEditingController(text: widget.entry.review);
    _rating = widget.entry.rating;
    _watchedDate = widget.entry.watchedDate;
    _isFavorite = widget.entry.isFavorite;
    _isRewatch = widget.entry.isRewatch;
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

  Future<void> _saveEntry() async {
    try {
      await FirebaseFirestore.instance
          .collection('diary_entries')
          .doc(widget.entry.id)
          .update({
            'review': _reviewController.text,
            'rating': _rating,
            'watchedDate': _watchedDate,
            'isFavorite': _isFavorite,
            'isRewatch': _isRewatch,
          });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating entry: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Diary Entry'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveEntry),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.entry.movieTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reviewController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Rating: '),
                const SizedBox(width: 8),
                ...List.generate(_rating.ceil(), (index) {
                  if (index < _rating.floor()) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _rating = index + 1.0;
                        });
                      },
                      child: Icon(
                        Icons.star,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  } else if (index == _rating.floor() && _rating % 1 >= 0.5) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _rating = index + 0.5;
                        });
                      },
                      child: Icon(
                        Icons.star_half,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  } else {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _rating = index + 1.0;
                        });
                      },
                      child: Icon(
                        Icons.star_outlined,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    );
                  }
                }),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Watched Date'),
              subtitle: Text(DateFormat('MMMM d, yyyy').format(_watchedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
            ),
            SwitchListTile(
              title: const Text('Favorite'),
              value: _isFavorite,
              onChanged: (value) {
                setState(() {
                  _isFavorite = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Rewatch'),
              value: _isRewatch,
              onChanged: (value) {
                setState(() {
                  _isRewatch = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
