import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/haptic_provider.dart';
import '../../core/services/adaptive_performance.dart';

class RoyalBottomNavBar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const RoyalBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  ConsumerState<RoyalBottomNavBar> createState() => _RoyalBottomNavBarState();
}

class _RoyalBottomNavBarState extends ConsumerState<RoyalBottomNavBar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  // Controller for the "breathing" glow effect
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  final List<NavTabItem> _items = [
    NavTabItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    NavTabItem(Icons.local_fire_department_rounded, Icons.local_fire_department_outlined, 'Feed'),
    NavTabItem(Icons.grid_view_rounded, Icons.grid_view_outlined, 'Explore'),
    NavTabItem(Icons.favorite_rounded, Icons.favorite_border_rounded, 'Favorites'),
    NavTabItem(Icons.download_rounded, Icons.download_outlined, 'Saved'),
    NavTabItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _animation = Tween<double>(
      begin: widget.selectedIndex.toDouble(),
      end: widget.selectedIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    ));

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void didUpdateWidget(RoyalBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateTo(widget.selectedIndex);
    }
  }

  void _animateTo(int targetIndex) {
    _animation = Tween<double>(
      begin: _animation.value,
      end: targetIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    ));

    _controller.reset();
    
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 160.0,
        damping: 22.0,
      ),
      0.0, 1.0, 0.0,
    );

    _controller.animateWith(simulation);
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Floating margins inspired by modern iOS designs
    const horizontalMargin = 20.0;
    const bottomMargin = 12.0;
    final navBarWidth = screenWidth - (horizontalMargin * 2);
    
    return Container(
      margin: EdgeInsets.only(
        left: horizontalMargin,
        right: horizontalMargin,
        bottom: bottomMargin + bottomPadding,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Builder(
          builder: (context) {
            final content = Container(
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: AdaptivePerformance.enableBackdropBlur ? 0.1 : 0.25),
                    Colors.white.withValues(alpha: AdaptivePerformance.enableBackdropBlur ? 0.05 : 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 1. Moving Selection Indicator (Subtle Glow Bloom)
                  AnimatedBuilder(
                    animation: Listenable.merge([_animation, _glowAnimation]),
                    builder: (context, child) {
                      final tabWidth = navBarWidth / _items.length;
                      final centerOffset = (_animation.value * tabWidth) + (tabWidth / 2);
                      
                      return Positioned(
                        left: centerOffset - 35,
                        top: 5,
                        child: Container(
                          width: 70,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFFD700).withValues(alpha: 0.18 * _glowAnimation.value),
                                const Color(0xFFFFD700).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // 2. Navigation Items Row
                  Row(
                    children: List.generate(_items.length, (index) {
                      final item = _items[index];
                      final isSelected = widget.selectedIndex == index;
                      
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (!isSelected) {
                              ref.read(hapticProvider.notifier).selectionClick();
                              widget.onItemSelected(index);
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: _NavBarItem(
                            item: item,
                            isSelected: isSelected,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
            
            return AdaptivePerformance.enableBackdropBlur
                ? BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                    child: content,
                  )
                : content;
          },
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final NavTabItem item;
  final bool isSelected;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, isSelected ? -2.0 : 0.0, 0.0, 1.0)
            ..scaleByDouble(isSelected ? 1.15 : 1.0, isSelected ? 1.15 : 1.0, 1.0, 1.0),
          child: ShaderMask(
            shaderCallback: (bounds) {
              if (!isSelected) {
                return LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.65),
                  ],
                ).createShader(bounds);
              }
              return const LinearGradient(
                colors: [Color(0xFFFFF2CD), Color(0xFFFFD700)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ).createShader(bounds);
            },
            child: Icon(
              isSelected ? item.activeIcon : item.inactiveIcon,
              color: Colors.white,
              shadows: isSelected ? [
                Shadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ] : null,
              size: 24,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            color: isSelected ? const Color(0xFFFFD700) : Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
            letterSpacing: 0.4,
          ),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class NavTabItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  NavTabItem(this.activeIcon, this.inactiveIcon, this.label);
}
