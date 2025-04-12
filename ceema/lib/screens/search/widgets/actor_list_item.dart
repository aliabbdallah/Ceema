import 'package:flutter/material.dart';
import '../../../screens/actor_details_screen.dart';

class ActorListItem extends StatelessWidget {
  final Map<String, dynamic> actor;

  const ActorListItem({Key? key, required this.actor}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final profilePath = actor['profile_path'];
    final profileUrl =
        profilePath != null
            ? 'https://image.tmdb.org/t/p/w500$profilePath'
            : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ActorDetailsScreen(actor: actor),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Actor profile image
              Hero(
                tag: 'actor_profile_${actor['id']}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      profileUrl != null
                          ? Image.network(
                            profileUrl,
                            width: 100,
                            height: 150,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 100,
                                height: 150,
                                color: colorScheme.surfaceVariant,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 150,
                                color: colorScheme.surfaceVariant,
                                child: Icon(
                                  Icons.person,
                                  size: 50,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          )
                          : Container(
                            width: 100,
                            height: 150,
                            color: colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.person,
                              size: 50,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                ),
              ),

              const SizedBox(width: 16),

              // Actor details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Actor name
                    Text(
                      actor['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Department and known for
                    Row(
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          actor['known_for_department'] ?? 'Actor',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Empty space for consistency
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
