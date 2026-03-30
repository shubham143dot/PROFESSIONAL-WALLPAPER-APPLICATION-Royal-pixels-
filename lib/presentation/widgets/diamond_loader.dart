import 'dart:math' as math;
import 'package:flutter/material.dart';

class DiamondLoader extends StatefulWidget {
  final double size;
  final Color color;

  const DiamondLoader({
    super.key,
    this.size = 50.0,
    this.color = Colors.amber, // Default to yellow/amber
  });

  @override
  State<DiamondLoader> createState() => _DiamondLoaderState();
}

class _DiamondLoaderState extends State<DiamondLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500), // Smooth 1.5s spin
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Continuous 3D Y-axis rotation
        final angle = _controller.value * 2 * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: child,
        );
      },
      child: Center(
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Icon(
            Icons.diamond, // Filled diamond for better 3D visibility
            size: widget.size,
            color: widget.color,
            shadows: [
              Shadow(
                color: widget.color.withValues(alpha: 0.6),
                blurRadius: 15, // Smooth glowing effect
              ),
            ],
          ),
        ),
      ),
    );
  }
}
