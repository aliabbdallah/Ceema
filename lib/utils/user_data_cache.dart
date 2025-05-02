import '../models/user.dart';

class UserDataCache {
  static final Map<String, UserModel> _cache = {};
  static final Duration _cacheDuration = const Duration(minutes: 5);

  static UserModel? get(String userId) {
    final user = _cache[userId];
    if (user == null) return null;
    if (DateTime.now().difference(user.createdAt) > _cacheDuration) {
      _cache.remove(userId);
      return null;
    }
    return user;
  }

  static void set(String userId, UserModel user) {
    _cache[userId] = user;
  }

  static void clear() {
    _cache.clear();
  }
}
