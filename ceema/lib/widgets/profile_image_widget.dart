import 'package:flutter/material.dart';

class ProfileImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String fallbackName;

  const ProfileImageWidget({
    Key? key,
    required this.imageUrl,
    this.radius = 50,
    this.fallbackName = '',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If no image URL, show a placeholder with the first letter of the name
    if (imageUrl == null || imageUrl!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        child: Text(
          fallbackName.isNotEmpty ? fallbackName[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: radius * 0.8,
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Check if the URL is for an asset or a network image
    if (imageUrl!.startsWith('assets/')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: AssetImage(imageUrl!),
      );
    } else if (imageUrl!.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // Silently handle error and show fallback
        },
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        child: Icon(
          Icons.person,
          size: radius,
          color: Theme.of(context).primaryColor,
        ),
      );
    }
  }
}
