import 'package:flutter/material.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String fallbackName;

  const ProfileImageWidget({
    Key? key,
    required this.imageUrl,
    this.radius = 100,
    this.fallbackName = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no image URL, show a placeholder with the first letter of the name
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onPrimaryContainer.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: radius * 0.8,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Check if the URL is for an asset or a network image
    if (imageUrl!.startsWith('assets/')) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onPrimaryContainer.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundImage: AssetImage(imageUrl!),
        ),
      );
    } else if (imageUrl!.startsWith('http')) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onPrimaryContainer.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(imageUrl!),
          onBackgroundImageError: (exception, stackTrace) {
            // Silently handle error and show fallback
          },
        ),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onPrimaryContainer.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.person,
            size: radius,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }
  }
}
