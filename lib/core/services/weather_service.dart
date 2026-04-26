import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

enum WeatherCondition { sunny, rainy, cloudy, stormy, foggy, snowy, unknown }

class WeatherService {
  // TODO: Move to a secure config
  static const String _apiKey = 'f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6'; // Placeholder

  Future<WeatherCondition> getCurrentCondition() async {
    try {
      final position = await _determinePosition();
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey';
      
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final main = data['weather'][0]['main'].toString().toLowerCase();
        return _mapToCondition(main);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WeatherService Error: $e');
      }
    }
    return WeatherCondition.unknown;
  }

  WeatherCondition _mapToCondition(String main) {
    if (main.contains('sun') || main.contains('clear')) return WeatherCondition.sunny;
    if (main.contains('rain') || main.contains('drizzle')) return WeatherCondition.rainy;
    if (main.contains('cloud')) return WeatherCondition.cloudy;
    if (main.contains('storm') || main.contains('thunder')) return WeatherCondition.stormy;
    if (main.contains('fog') || main.contains('mist') || main.contains('haze')) return WeatherCondition.foggy;
    if (main.contains('snow')) return WeatherCondition.snowy;
    return WeatherCondition.unknown;
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services are disabled.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Location permissions are denied');
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  List<String> getTagsForWeather(WeatherCondition condition) {
    switch (condition) {
      case WeatherCondition.sunny: return ['nature', 'bright', 'sunrise', 'warm', 'sky'];
      case WeatherCondition.rainy: return ['dark', 'moody', 'minimal', 'forest', 'rain'];
      case WeatherCondition.stormy: return ['lightning', 'dramatic', 'dark', 'cyberpunk'];
      case WeatherCondition.foggy: return ['minimal', 'misty', 'soft', 'abstract'];
      case WeatherCondition.snowy: return ['winter', 'white', 'minimal', 'nature'];
      default: return [];
    }
  }
}
