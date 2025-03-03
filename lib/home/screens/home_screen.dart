import 'package:flutter/material.dart';
import '../components/feed_screen.dart';
import 'package:ceema/screens/profile_screen.dart';
import 'package:ceema/screens/diary_screen.dart';
import 'package:ceema/screens/mood_entry_point_screen.dart';
import 'package:ceema/screens/friends_screen.dart';
import 'package:ceema/screens/watchlist_screen.dart';
import 'package:ceema/screens/timeline_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
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
    final List<Widget> screens = [
      const FeedScreen(),
      const MoodEntryPointScreen(),
      const DiaryScreen(),
      const WatchlistScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: PageView(
          controller: _pageController,
          physics: _isPageChanging
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          onPageChanged: (index) {
            if (!_isPageChanging) {
              setState(() => _currentTab = index);
            }
          },
          children: screens,
        ),
      ),
      floatingActionButton: _currentTab == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 70.0, right: 16.0),
              child: FloatingActionButton(
                heroTag: 'timeline_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TimelineScreen(),
                    ),
                  );
                },
                backgroundColor: colorScheme.tertiary,
                child: const Icon(Icons.timeline),
                tooltip: 'View Timeline',
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        elevation: 8,
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        selectedIndex: _currentTab,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        animationDuration: const Duration(milliseconds: 500),
        onDestinationSelected: _changePage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
            tooltip: 'Home Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.mood_outlined),
            selectedIcon: Icon(Icons.mood),
            label: 'Mood',
            tooltip: 'Mood Recommendations',
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
