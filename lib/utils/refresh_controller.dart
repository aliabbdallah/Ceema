class FeedRefreshController {
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;
  final Duration _minRefreshInterval = const Duration(seconds: 2);

  bool get isRefreshing => _isRefreshing;

  bool canRefresh() {
    if (_lastRefreshTime == null) return true;
    return DateTime.now().difference(_lastRefreshTime!) > _minRefreshInterval;
  }

  Future<void> startRefresh() async {
    if (!canRefresh()) return;
    _isRefreshing = true;
    _lastRefreshTime = DateTime.now();
  }

  void completeRefresh() {
    _isRefreshing = false;
  }
}
