import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/theme/app_colors.dart';

final weatherProvider = FutureProvider<WeatherCondition>((ref) async {
  return await WeatherService().getCurrentCondition();
});

class WeatherBanner extends ConsumerWidget {
  const WeatherBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);

    return weatherAsync.when(
      data: (condition) => _buildBanner(context, condition),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context, WeatherCondition condition) {
    if (condition == WeatherCondition.unknown) return const SizedBox.shrink();

    final config = _getWeatherConfig(condition);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [config.color.withValues(alpha: 0.8), config.color.withValues(alpha: 0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(config.icon, color: Colors.white, size: 32)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 3.seconds),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  config.subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  _WeatherConfig _getWeatherConfig(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny:
        return _WeatherConfig(
          icon: Icons.wb_sunny_rounded,
          title: 'Bright & Sunny Today',
          subtitle: 'Perfect time for vibrant wallpapers',
          color: Colors.orange,
        );
      case WeatherCondition.rainy:
        return _WeatherConfig(
          icon: Icons.umbrella_rounded,
          title: 'Moody Rainy Vibes',
          subtitle: 'Check out our dark nature collection',
          color: Colors.indigo,
        );
      case WeatherCondition.stormy:
        return _WeatherConfig(
          icon: Icons.thunderstorm_rounded,
          title: 'Electric Storm Outside',
          subtitle: 'Dramatic wallpapers for a bold look',
          color: Colors.purple,
        );
      case WeatherCondition.cloudy:
        return _WeatherConfig(
          icon: Icons.cloud_rounded,
          title: 'Calm Cloudy Day',
          subtitle: 'Soft minimal picks for focus',
          color: Colors.blueGrey,
        );
      default:
        return _WeatherConfig(
          icon: Icons.wb_cloudy_rounded,
          title: 'Reactive Wallpapers',
          subtitle: 'Curated based on your environment',
          color: AppColors.goldMid,
        );
    }
  }
}

class _WeatherConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  _WeatherConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
}
