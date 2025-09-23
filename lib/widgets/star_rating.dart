import 'package:flutter/material.dart';

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
  })  : assert(rating >= 0),
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
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.4, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
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

    // Calculate the position within the star (0.0 to 1.0)
    final starPosition =
        (localPosition.dx - (starIndex * starWidth)) / widget.size;

    // Calculate the rating
    double rating;
    if (widget.allowHalfRating) {
      // For half-star precision
      rating = starIndex + (starPosition > 0.5 ? 1.0 : 0.5);
    } else {
      // For full-star precision
      rating = starIndex + (starPosition > 0.5 ? 1.0 : 0.0);
    }

    // Ensure the rating is within bounds
    return rating.clamp(0.0, widget.maxRating.toDouble());
  }

  void _handleTap(Offset globalPosition) {
    if (widget.readOnly) return;

    final newRating = _calculateRating(globalPosition);

    if (newRating != _rating) {
      setState(() {
        _rating = newRating;
      });

      // Play animation
      _controller.forward(from: 0.0);

      // Notify listener
      widget.onRatingChanged?.call(_rating);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.readOnly
          ? null
          : (details) => _handleTap(details.globalPosition),
      onHorizontalDragUpdate: widget.readOnly
          ? null
          : (details) => _handleTap(details.globalPosition),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: widget.alignment,
        children: List.generate(widget.maxRating, (index) {
          return Padding(
            padding: EdgeInsets.only(
                right: index < widget.maxRating - 1 ? widget.spacing : 0),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Apply animation only to the stars that are being filled
                final isAnimated = index < _rating && index >= _rating - 1;
                final scale = isAnimated ? _sizeAnimation.value : 1.0;

                return Transform.scale(
                  scale: scale,
                  child: Stack(
                    children: [
                      _buildStar(index),
                      if (isAnimated)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withOpacity(_opacityAnimation.value),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStar(int index) {
    final starValue = index + 1;

    // Full star
    if (starValue <= _rating) {
      return Icon(
        Icons.star,
        color: widget.activeColor,
        size: widget.size,
      );
    }
    // Half star
    else if (starValue - 0.5 <= _rating && widget.allowHalfRating) {
      return Icon(
        Icons.star_half,
        color: widget.activeColor,
        size: widget.size,
      );
    }
    // Empty star
    else {
      return Icon(
        Icons.star_border,
        color: widget.inactiveColor,
        size: widget.size,
      );
    }
  }
}
