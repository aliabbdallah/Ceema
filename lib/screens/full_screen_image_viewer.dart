import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:ui';
import 'dart:math' as math;

class FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  final String? fallbackText;

  const FullScreenImageViewer({
    Key? key,
    required this.imageUrl,
    this.fallbackText,
  }) : super(key: key);

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Offset _dragStart = Offset.zero;
  bool _isDragging = false;
  bool _isImageTapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStart = details.globalPosition;
    _isDragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;

    final currentPosition = details.globalPosition;
    final offset = currentPosition - _dragStart;

    // Calculate the drag distance as a percentage of screen size
    final dragDistance = math.sqrt(
      math.pow(offset.dx / MediaQuery.of(context).size.width, 2) +
          math.pow(offset.dy / MediaQuery.of(context).size.height, 2),
    );

    // Update the position of the image
    setState(() {
      _controller.value = dragDistance.clamp(0.0, 1.0);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final velocity = (details.primaryVelocity ?? 0).abs();
    final dragDistance = _controller.value;

    // If dragged more than 20% of screen size or with significant velocity, dismiss
    if (dragDistance > 0.2 || velocity > 500) {
      _controller.forward().then((_) => Navigator.pop(context));
    } else {
      _controller.reverse();
    }

    _isDragging = false;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Blurred background with tap to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),
          ),

          // Main content
          Center(
            child: SlideTransition(
              position: _offsetAnimation,
              child: GestureDetector(
                onPanStart: _handleDragStart,
                onPanUpdate: _handleDragUpdate,
                onPanEnd: _handleDragEnd,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.6,
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: PhotoView(
                    imageProvider: NetworkImage(widget.imageUrl),
                    loadingBuilder:
                        (context, event) => Center(
                          child: CircularProgressIndicator(
                            value:
                                event?.expectedTotalBytes != null
                                    ? event!.cumulativeBytesLoaded /
                                        event.expectedTotalBytes!
                                    : null,
                          ),
                        ),
                    errorBuilder:
                        (context, error, stackTrace) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.white,
                                size: 48,
                              ),
                              if (widget.fallbackText != null) ...[
                                SizedBox(height: 16),
                                Text(
                                  widget.fallbackText!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    backgroundDecoration: BoxDecoration(
                      color: Colors.transparent,
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                    initialScale: PhotoViewComputedScale.contained,
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: widget.imageUrl,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
