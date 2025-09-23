import 'package:flutter/material.dart';

class ProfileImageWidget extends StatefulWidget {
  final String? imageUrl;
  final double radius;
  final String fallbackName;
  final VoidCallback? onTap;

  const ProfileImageWidget({
    Key? key,
    required this.imageUrl,
    this.radius = 100,
    this.fallbackName = '',
    this.onTap,
  }) : super(key: key);

  @override
  State<ProfileImageWidget> createState() => _ProfileImageWidgetState();
}

class _ProfileImageWidgetState extends State<ProfileImageWidget> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // If no image URL or error, show initials
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty || _hasError) {
      return GestureDetector(
        onTap: widget.onTap,
        child: CircleAvatar(
          radius: widget.radius,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          child: Text(
            widget.fallbackName.isNotEmpty
                ? widget.fallbackName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: widget.radius * 0.6,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Check if the URL is for an asset or a network image
    if (widget.imageUrl!.startsWith('assets/')) {
      return GestureDetector(
        onTap: widget.onTap,
        child: CircleAvatar(
          radius: widget.radius,
          backgroundImage: AssetImage(widget.imageUrl!),
          onBackgroundImageError: (exception, stackTrace) {
            setState(() {
              _hasError = true;
            });
          },
        ),
      );
    } else if (widget.imageUrl!.startsWith('http')) {
      return GestureDetector(
        onTap: widget.onTap,
        child: CircleAvatar(
          radius: widget.radius,
          backgroundImage: NetworkImage(widget.imageUrl!),
          onBackgroundImageError: (exception, stackTrace) {
            setState(() {
              _hasError = true;
            });
          },
        ),
      );
    } else {
      // If the URL is neither an asset nor a network URL, show initials
      return GestureDetector(
        onTap: widget.onTap,
        child: CircleAvatar(
          radius: widget.radius,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          child: Text(
            widget.fallbackName.isNotEmpty
                ? widget.fallbackName[0].toUpperCase()
                : '?',
            style: TextStyle(
              fontSize: widget.radius * 0.6,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
  }
}
