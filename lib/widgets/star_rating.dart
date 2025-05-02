import 'package:flutter/material.dart';
import '../services/haptic_service.dart';

class StarRating extends StatefulWidget {
  final double rating;
  final double size;
  final int maxRating;
  final bool allowHalfRating;
  final bool readOnly;
  final ValueChanged<double>? onRatingChanged;
  final Color activeColor;
  final Color inactiveColor;
  final MainAxisAlignment alignment;
  final double spacing;

  const StarRating({
    Key? key,
    this.rating = 0.0,
    this.size = 24.0,
    this.maxRating = 5,
    this.allowHalfRating = true,
    this.readOnly = false,
    this.onRatingChanged,
    this.activeColor = Colors.amber,
    this.inactiveColor = Colors.grey,
    this.alignment = MainAxisAlignment.center,
    this.spacing = 0.0,
  }) : assert(rating >= 0),
       assert(maxRating > 0),
       super(key: key);

  @override
  _StarRatingState createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating>
    with SingleTickerProviderStateMixin {
  late double _rating;
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late Animation<double> _opacityAnimation;
  final HapticService _hapticService = HapticService();

  @override
  void initState() {
    super.initState();
    _rating = widget.rating;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sizeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 0.4,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.4,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StarRating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rating != widget.rating) {
      _rating = widget.rating;
    }
  }

  double _calculateRating(Offset globalPosition) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(globalPosition);

    // Calculate the width of each star (including spacing)
    final starWidth = widget.size + widget.spacing;

    // Calculate which star was tapped
    final starIndex = (localPosition.dx / starWidth).floor();
    final starFraction = (localPosition.dx % starWidth) / starWidth;

    // Calculate the rating based on the tap position
    double rating;
    if (widget.allowHalfRating) {
      rating = starIndex + (starFraction > 0.5 ? 1.0 : 0.5);
    } else {
      rating = starIndex + 1.0;
    }

    // Clamp the rating between 0 and maxRating
    return rating.clamp(0.0, widget.maxRating.toDouble());
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.readOnly) return;
    final newRating = _calculateRating(details.globalPosition);
    setState(() => _rating = newRating);
    _controller.forward(from: 0.0);
    _hapticService.light();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.readOnly) return;
    final newRating = _calculateRating(details.globalPosition);
    if (widget.onRatingChanged != null) {
      widget.onRatingChanged!(newRating);
    }
    _hapticService.medium();
  }

  void _handleTapCancel() {
    if (widget.readOnly) return;
    setState(() => _rating = widget.rating);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Row(
        mainAxisAlignment: widget.alignment,
        children: List.generate(widget.maxRating, (index) {
          final starValue = index + 1.0;
          final isHalfStar = _rating >= starValue - 0.5 && _rating < starValue;
          final isFullStar = _rating >= starValue;

          return Padding(
            padding: EdgeInsets.only(
              right: index < widget.maxRating - 1 ? widget.spacing : 0,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: isFullStar ? _sizeAnimation.value : 1.0,
                  child: Opacity(
                    opacity: isFullStar ? 1.0 - _opacityAnimation.value : 1.0,
                    child: Icon(
                      isFullStar
                          ? Icons.star
                          : isHalfStar
                          ? Icons.star_half
                          : Icons.star_border,
                      size: widget.size,
                      color:
                          isFullStar || isHalfStar
                              ? widget.activeColor
                              : widget.inactiveColor,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
