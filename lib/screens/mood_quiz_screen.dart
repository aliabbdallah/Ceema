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

class _MoodQuizScreenState extends State<MoodQuizScreen> with SingleTickerProviderStateMixin {
  final List<Mood> _moods = MoodData.getMoods();
  String? _selectedMoodId;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      
      // Save user's mood selection for future personalization
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await MoodRecommendationService.saveUserMoodSelection(
          user.uid, 
          _selectedMoodId!,
        );
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MoodRecommendationsScreen(mood: selectedMood),
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
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 120,
                        child: Lottie.asset(
                          'assets/animations/mood_animation.json', // Mood animation
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
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: MoodCard(
                        mood: mood,
                        isSelected: _selectedMoodId == mood.id,
                        onTap: () => _selectMood(mood.id),
                      ),
                    );
                  },
                  childCount: _moods.length,
                ),
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
