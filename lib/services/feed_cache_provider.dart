import 'package:flutter/material.dart';
import 'feed_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedCacheProvider extends ChangeNotifier {
  late FeedCacheService _cacheService;
  bool _isInitialized = false;

  FeedCacheService get cacheService => _cacheService;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _cacheService = FeedCacheService(prefs);
    _cacheService.startBackgroundUpdates();
    _isInitialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _cacheService.dispose();
    super.dispose();
  }
}
