import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/mood.dart';

class MoodCard extends StatelessWidget {
  final Mood mood;
  final bool isSelected;
  final VoidCallback onTap;

  const MoodCard({
    Key? key,
    required this.mood,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  // Parse hex color string to Color
  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.blue; // Default color if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = _parseColor(mood.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Hero(
      tag: 'mood_${mood.id}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutQuart,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? moodColor.withOpacity(0.95)
                  : (isDark
                      ? Colors.black.withOpacity(0.7)
                      : Colors.white.withOpacity(0.9)),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : moodColor.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? moodColor.withOpacity(0.4)
                      : (isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.black.withOpacity(0.05)),
                  blurRadius: isSelected ? 15 : 8,
                  offset: Offset(0, isSelected ? 5 : 3),
                ),
                if (isSelected)
                  BoxShadow(
                    color: moodColor.withOpacity(0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
              ],
            ),
            child: Stack(
              children: [
                // Background pattern
                if (isSelected)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: CustomPaint(
                        painter: MoodPatternPainter(
                          color: moodColor,
                          patternOpacity: 0.1,
                        ),
                      ),
                    ),
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Emoji with scale animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: isSelected ? 1.0 : 0.9,
                          end: isSelected ? 1.2 : 1.0,
                        ),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Text(
                          mood.emoji,
                          style: const TextStyle(
                            fontSize: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Mood name
                      Text(
                        mood.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black87),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Mood description
                      Text(
                        mood.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white.withOpacity(0.9)
                              : (isDark
                                  ? Colors.white.withOpacity(0.7)
                                  : Colors.black54),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Selection indicator
                if (isSelected)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: moodColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: moodColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for the background pattern
class MoodPatternPainter extends CustomPainter {
  final Color color;
  final double patternOpacity;

  MoodPatternPainter({
    required this.color,
    this.patternOpacity = 0.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(patternOpacity)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const spacing = 20.0;
    final rows = (size.height / spacing).ceil();
    final cols = (size.width / spacing).ceil();

    for (var i = 0; i < rows; i++) {
      for (var j = 0; j < cols; j++) {
        final x = j * spacing;
        final y = i * spacing;

        // Draw small circles in a grid pattern
        canvas.drawCircle(
          Offset(x, y),
          3,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(MoodPatternPainter oldDelegate) =>
      color != oldDelegate.color ||
      patternOpacity != oldDelegate.patternOpacity;
}
