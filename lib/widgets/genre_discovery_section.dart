// widgets/genre_discovery_section.dart
import 'package:flutter/material.dart';

class GenreDiscoverySection extends StatelessWidget {
  final String genre;
  final Function(String) onGenreSelected;
  final bool isSelected;
  final Color? color;
  final IconData? icon;

  const GenreDiscoverySection({
    Key? key,
    required this.genre,
    required this.onGenreSelected,
    this.isSelected = false,
    this.color,
    this.icon,
  }) : super(key: key);

  // Get appropriate icon for each genre
  IconData _getGenreIcon() {
    if (icon != null) return icon!;

    switch (genre.toLowerCase()) {
      case 'action':
        return Icons.local_fire_department;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      case 'drama':
        return Icons.theater_comedy;
      case 'thriller':
        return Icons.psychology;
      case 'horror':
        return Icons.front_hand;
      case 'romance':
        return Icons.favorite;
      case 'sci-fi':
      case 'science fiction':
        return Icons.rocket;
      case 'fantasy':
        return Icons.auto_fix_high;
      case 'animation':
        return Icons.animation;
      case 'adventure':
        return Icons.explore;
      case 'documentary':
        return Icons.camera_alt;
      case 'family':
        return Icons.family_restroom;
      case 'musical':
      case 'music':
        return Icons.music_note;
      case 'mystery':
        return Icons.search;
      case 'war':
        return Icons.shield;
      case 'western':
        return Icons.agriculture;
      default:
        return Icons.movie;
    }
  }

  // Get appropriate color for each genre
  Color _getGenreColor(BuildContext context) {
    if (color != null) return color!;

    final colorScheme = Theme.of(context).colorScheme;

    switch (genre.toLowerCase()) {
      case 'action':
        return Colors.red;
      case 'comedy':
        return Colors.amber;
      case 'drama':
        return Colors.blue.shade800;
      case 'thriller':
        return Colors.deepPurple;
      case 'horror':
        return Colors.black87;
      case 'romance':
        return Colors.pink;
      case 'sci-fi':
      case 'science fiction':
        return Colors.teal;
      case 'fantasy':
        return Colors.indigo;
      case 'animation':
        return Colors.orange;
      case 'adventure':
        return Colors.green;
      case 'documentary':
        return Colors.brown;
      case 'family':
        return Colors.cyan;
      case 'musical':
      case 'music':
        return Colors.deepOrange;
      case 'mystery':
        return Colors.blueGrey;
      case 'war':
        return Colors.grey.shade800;
      case 'western':
        return Colors.amber.shade800;
      default:
        return colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final genreColor = _getGenreColor(context);
    final genreIcon = _getGenreIcon();

    return GestureDetector(
      onTap: () => onGenreSelected(genre),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? genreColor.withOpacity(0.8)
              : genreColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? genreColor : genreColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.3)
                    : genreColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                genreIcon,
                color: isSelected ? Colors.white : genreColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              genre,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : genreColor.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class GenreDiscoveryRow extends StatefulWidget {
  final Function(String) onGenreSelected;
  final String initialGenre;

  const GenreDiscoveryRow({
    Key? key,
    required this.onGenreSelected,
    this.initialGenre = 'Action',
  }) : super(key: key);

  @override
  _GenreDiscoveryRowState createState() => _GenreDiscoveryRowState();
}

class _GenreDiscoveryRowState extends State<GenreDiscoveryRow> {
  late String _selectedGenre;
  final List<String> _genres = [
    'Action',
    'Comedy',
    'Drama',
    'Thriller',
    'Horror',
    'Romance',
    'Sci-Fi',
    'Fantasy',
    'Animation',
    'Adventure',
  ];

  @override
  void initState() {
    super.initState();
    _selectedGenre = widget.initialGenre;
  }

  void _selectGenre(String genre) {
    setState(() {
      _selectedGenre = genre;
    });
    widget.onGenreSelected(genre);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Explore by Genre',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _genres.length,
            itemBuilder: (context, index) {
              final genre = _genres[index];
              return GenreDiscoverySection(
                genre: genre,
                isSelected: genre == _selectedGenre,
                onGenreSelected: _selectGenre,
              );
            },
          ),
        ),
      ],
    );
  }
}
