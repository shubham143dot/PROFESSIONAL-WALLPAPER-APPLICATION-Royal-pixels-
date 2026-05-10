import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/services/weather_service.dart';
import '../../../core/services/adaptive_performance.dart';

final weatherProvider = FutureProvider<WeatherCondition>((ref) async {
  return await WeatherService().getCurrentCondition();
});

class WeatherBanner extends ConsumerWidget {
  const WeatherBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);

    return weatherAsync.when(
      data: (condition) => condition == WeatherCondition.unknown
          ? const SizedBox.shrink()
          : _buildBanner(context, condition),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context, WeatherCondition condition) {
    final config = _getWeatherConfig(condition);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: config.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: config.colors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(config.icon, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getWeatherLabel(condition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Perfect vibes for your home screen',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'REEL',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).animate(target: AdaptivePerformance.enableAnimations ? null : 1.0).fadeIn().slideX(begin: 0.1);
  }

  String _getWeatherLabel(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny: return 'Sunny Day Vibes';
      case WeatherCondition.rainy: return 'Cozy Rainy Day';
      case WeatherCondition.cloudy: return 'Cloudy Skies';
      case WeatherCondition.stormy: return 'Electric Storm';
      case WeatherCondition.foggy: return 'Misty Morning';
      case WeatherCondition.snowy: return 'Winter Wonderland';
      default: return 'Good Vibes';
    }
  }

  _WeatherConfig _getWeatherConfig(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.stormy:
        return _WeatherConfig(
            [const Color(0xFF4B6CB7), const Color(0xFF182848)],
            Icons.bolt_rounded);
      case WeatherCondition.rainy:
        return _WeatherConfig(
            [const Color(0xFF4CA1AF), const Color(0xFF2C3E50)],
            Icons.grain_rounded);
      case WeatherCondition.snowy:
        return _WeatherConfig(
            [const Color(0xFF83a4d4), const Color(0xFFb6fbff)],
            Icons.ac_unit_rounded);
      case WeatherCondition.sunny:
        return _WeatherConfig(
            [const Color(0xFF2980B9), const Color(0xFF6DD5FA)],
            Icons.wb_sunny_rounded);
      case WeatherCondition.cloudy:
        return _WeatherConfig(
            [const Color(0xFF757F9A), const Color(0xFFD7DDE8)],
            Icons.cloud_rounded);
      case WeatherCondition.foggy:
        return _WeatherConfig(
            [const Color(0xFF3E5151), const Color(0xFFDECBA4)],
            Icons.wb_cloudy_rounded);
      default:
        return _WeatherConfig(
            [const Color(0xFF2c3e50), const Color(0xFF000000)],
            Icons.wb_cloudy_rounded);
    }
  }
}

class _WeatherConfig {
  final List<Color> colors;
  final IconData icon;

  _WeatherConfig(this.colors, this.icon);
}
