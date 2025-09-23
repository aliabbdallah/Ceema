import 'package:flutter/material.dart';
import '../widgets/actor_list_item.dart';

class ActorSearchTab extends StatelessWidget {
  final List<Map<String, dynamic>> actorResults;
  final bool isLoading;
  final bool isSearchActive;

  const ActorSearchTab({
    Key? key,
    required this.actorResults,
    required this.isLoading,
    required this.isSearchActive,
  }) : super(key: key);

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No actors found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Search Actors',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text('Find actors by name', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isSearchActive && actorResults.isEmpty) {
      return _buildEmptyState();
    }

    if (actorResults.isNotEmpty) {
      return ListView.builder(
        itemCount: actorResults.length,
        itemBuilder:
            (context, index) => ActorListItem(actor: actorResults[index]),
      );
    }

    return _buildInitialState();
  }
}
