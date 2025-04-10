import 'package:flutter/material.dart';
import '../components/feed_screen.dart';
import 'package:ceema/screens/diary_screen.dart';
import 'package:ceema/screens/profile_screen.dart';
import 'package:ceema/screens/watchlist_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentTab = 0;
  bool _isPageChanging = false;
  bool _isInitializing = true;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Mark initialization as complete
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _changePage(int index) {
    if (_currentTab == index) return;

    setState(() {
      _isPageChanging = true;
    });

    _animationController.reverse().then((_) {
      _pageController.jumpToPage(index);
      setState(() {
        _currentTab = index;
      });
      _animationController.forward().then((_) {
        setState(() {
          _isPageChanging = false;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = _auth.currentUser;
    final List<Widget> screens = [
      const SeamlessFeedScreen(),
      const DiaryScreen(),
      WatchlistScreen(userId: currentUser?.uid ?? '', isCurrentUser: true),
      ProfileScreen(userId: currentUser?.uid ?? '', isCurrentUser: true),
    ];

    return Scaffold(
      // Show loading indicator if preferences are being initialized
      body:
          _isInitializing
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Personalizing your experience...'),
                  ],
                ),
              )
              : FadeTransition(
                opacity: _fadeAnimation,
                child: PageView(
                  controller: _pageController,
                  physics:
                      _isPageChanging
                          ? const NeverScrollableScrollPhysics()
                          : const NeverScrollableScrollPhysics(), // Disable swipe to change tabs
                  onPageChanged: (index) {
                    if (!_isPageChanging) {
                      setState(() => _currentTab = index);
                    }
                  },
                  children: screens,
                ),
              ),
      bottomNavigationBar: NavigationBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIndex: _currentTab,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        animationDuration: const Duration(milliseconds: 300),
        onDestinationSelected: _changePage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
            tooltip: 'Home Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Diary',
            tooltip: 'Movie Diary',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Watchlist',
            tooltip: 'Movie Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
            tooltip: 'Your Profile',
          ),
        ],
      ),
    );
  }
}
