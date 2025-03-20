import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../models/mood.dart';
import '../widgets/mood_card.dart';
import '../services/mood_recommendation_service.dart';
import 'mood_recommendations_screen.dart';

class MoodQuizScreen extends StatefulWidget {
  const MoodQuizScreen({Key? key}) : super(key: key);

  @override
  _MoodQuizScreenState createState() => _MoodQuizScreenState();
}

class _MoodQuizScreenState extends State<MoodQuizScreen>
    with SingleTickerProviderStateMixin {
  final List<Mood> _moods = MoodData.getMoods();
  String? _selectedMoodId;
  double _moodIntensity = 0.5; // Default intensity
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Map<String, dynamic>> _recentMoods = []; // Store recent mood selections

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
    _loadRecentMoods();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentMoods() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final recentMoods =
            await MoodRecommendationService.getRecentMoods(user.uid);
        if (mounted) {
          setState(() {
            _recentMoods = recentMoods;
          });
        }
      } catch (e) {
        print('Error loading recent moods: $e');
      }
    }
  }

  void _selectMood(String moodId) {
    setState(() {
      _selectedMoodId = moodId;
    });
  }

  Future<void> _getRecommendations() async {
    if (_selectedMoodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a mood first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final selectedMood = MoodData.getMoodById(_selectedMoodId!);

      // Save user's mood selection with intensity for future personalization
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await MoodRecommendationService.saveUserMoodSelection(
          user.uid,
          _selectedMoodId!,
          intensity: _moodIntensity,
        );
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MoodRecommendationsScreen(
              mood: selectedMood,
              intensity: _moodIntensity,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildRecentMoods() {
    if (_recentMoods.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Moods',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _recentMoods.map((moodData) {
                final mood = MoodData.getMoodById(moodData['moodId']);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message:
                        '${mood.name} (${(moodData['intensity'] * 100).round()}%)',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMoodId = mood.id;
                          _moodIntensity = moodData['intensity'] ?? 0.5;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _parseColor(mood.color).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Text(
                              mood.emoji,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              mood.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensitySlider() {
    if (_selectedMoodId == null) return const SizedBox.shrink();

    final selectedMood = MoodData.getMoodById(_selectedMoodId!);
    final moodColor = _parseColor(selectedMood.color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Intensity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(_moodIntensity * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: moodColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: moodColor,
              inactiveTrackColor: moodColor.withOpacity(0.2),
              thumbColor: moodColor,
              overlayColor: moodColor.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _moodIntensity,
              onChanged: (value) {
                setState(() {
                  _moodIntensity = value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to parse color
  Color _parseColor(String hexColor) {
    try {
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How are you feeling today?'),
        elevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header with animation
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 150,
                          child: Lottie.asset(
                            'assets/animations/mood_animation.json',
                            repeat: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Select your current mood and we\'ll recommend movies that match how you\'re feeling',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Recent moods section
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildRecentMoods(),
              ),
            ),

            // Mood grid
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final mood = _moods[index];
                    return SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: MoodCard(
                          mood: mood,
                          isSelected: _selectedMoodId == mood.id,
                          onTap: () => _selectMood(mood.id),
                        ),
                      ),
                    );
                  },
                  childCount: _moods.length,
                ),
              ),
            ),

            // Intensity slider
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildIntensitySlider(),
              ),
            ),

            // Get recommendations button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _getRecommendations,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Get Recommendations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
