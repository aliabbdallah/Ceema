import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home/screens/home_screen.dart';
import '../screens/diary_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/watchlist_screen.dart';
import '../screens/search_screen.dart';
import '../services/haptic_service.dart';
import 'navigation_service.dart';

class AppNavigator extends StatefulWidget {
  const AppNavigator({Key? key}) : super(key: key);

  @override
  AppNavigatorState createState() => AppNavigatorState();
}

class AppNavigatorState extends State<AppNavigator> {
  final PageController _pageController = PageController();
  int _currentTab = 0;
  bool _isPageChanging = false;
  final _auth = FirebaseAuth.instance;
  final _hapticService = HapticService();
  final _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    NavigationService().setNavigatorKeys(_navigatorKeys);
  }

  void _changePage(int index) async {
    if (_currentTab == index) {
      // If clicking the current tab, pop to root
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      await _hapticService.light();
      return;
    }

    // If switching to a different tab, pop all routes in the current tab
    _navigatorKeys[_currentTab].currentState?.popUntil(
      (route) => route.isFirst,
    );

    setState(() {
      _isPageChanging = true;
      _currentTab = index;
      _pageController.jumpToPage(index);
      _isPageChanging = false;
    });

    await _hapticService.medium();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUser = _auth.currentUser;

    return WillPopScope(
      onWillPop: () async {
        final currentNavigator = _navigatorKeys[_currentTab].currentState;
        if (currentNavigator != null) {
          if (currentNavigator.canPop()) {
            currentNavigator.pop();
            await _hapticService.light();
            return false;
          }
        }
        return true;
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (index) async {
            if (!_isPageChanging) {
              setState(() => _currentTab = index);
              await _hapticService.medium();
            }
          },
          children: [
            Navigator(
              key: _navigatorKeys[0],
              initialRoute: '/',
              onGenerateRoute: (settings) {
                if (settings.name == '/') {
                  return MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  );
                }
                return null;
              },
            ),
            Navigator(
              key: _navigatorKeys[1],
              initialRoute: '/',
              onGenerateRoute: (settings) {
                if (settings.name == '/') {
                  return MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  );
                }
                return null;
              },
            ),
            Navigator(
              key: _navigatorKeys[2],
              initialRoute: '/',
              onGenerateRoute: (settings) {
                if (settings.name == '/') {
                  return MaterialPageRoute(
                    builder: (context) => const DiaryScreen(),
                  );
                }
                return null;
              },
            ),
            Navigator(
              key: _navigatorKeys[3],
              initialRoute: '/',
              onGenerateRoute: (settings) {
                if (settings.name == '/') {
                  return MaterialPageRoute(
                    builder:
                        (context) => WatchlistScreen(
                          userId: currentUser?.uid ?? '',
                          isCurrentUser: true,
                        ),
                  );
                }
                return null;
              },
            ),
            Navigator(
              key: _navigatorKeys[4],
              initialRoute: '/',
              onGenerateRoute: (settings) {
                if (settings.name == '/') {
                  return MaterialPageRoute(
                    builder:
                        (context) => ProfileScreen(
                          userId: currentUser?.uid ?? '',
                          isCurrentUser: true,
                        ),
                  );
                }
                return null;
              },
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          elevation: 2,
          backgroundColor: colorScheme.surface.withOpacity(0.10),
          indicatorColor: colorScheme.secondary,
          selectedIndex: _currentTab,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          animationDuration: const Duration(milliseconds: 300),
          onDestinationSelected: _changePage,
          height: 64,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
              tooltip: 'Home Feed',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
              tooltip: 'Search Movies',
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
      ),
    );
  }
}
