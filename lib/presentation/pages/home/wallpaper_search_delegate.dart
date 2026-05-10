import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/theme/app_colors.dart';
import '../../../domain/entities/wallpaper_entity.dart';
import '../../widgets/wallpaper_card.dart';
import '../../../core/scroll/elite_scroll_physics.dart';
import '../../../core/services/adaptive_performance.dart';

class WallpaperSearchDelegate extends SearchDelegate<WallpaperEntity?> {
  final List<WallpaperEntity> allWallpapers;

  WallpaperSearchDelegate(this.allWallpapers);

  @override
  String get searchFieldLabel => 'Search wallpapers...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white54),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  List<WallpaperEntity> _getResults() {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    return allWallpapers.where((w) {
      return w.title.toLowerCase().contains(q) ||
          w.category.toLowerCase().contains(q) ||
          w.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.mic, color: AppColors.goldLight),
        onPressed: () => _startVoiceSearch(context),
      ),
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  Future<void> _startVoiceSearch(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) return;
    }
    if (status.isPermanentlyDenied) {
      openAppSettings();
      return;
    }

    final speech = stt.SpeechToText();
    bool available = await speech.initialize();
    if (!available) return;

    String recognisedWords = '';
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _MicSheet(
        speech: speech,
        onWordsFinal: (words) {
          recognisedWords = words;
        },
      ),
    );
    if (!context.mounted) return;
    if (recognisedWords.trim().isNotEmpty) {
      query = recognisedWords.trim();
      showResults(context);
    }
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context, _getResults());
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context, _getResults());
  }

  Widget _buildList(BuildContext context, List<WallpaperEntity> results) {
    if (query.trim().isEmpty) {
      return Container(
        color: const Color(0xFF121212),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 64, color: Colors.white24),
              SizedBox(height: 16),
              AnimatedSearchSuggestions(),
            ],
          ),
        ),
      );
    }

    if (results.isEmpty) {
      return Container(
        color: const Color(0xFF121212),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                'No results for "$query"',
                style: const TextStyle(color: Colors.white38, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF121212),
      child: GridView.builder(
        physics: const EliteAlwaysScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final wp = results[index];
          return WallpaperCard(
            wallpaper: wp,
            onTap: () {
              close(context, wp);
              context.push('/detail', extra: wp);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Search Suggestions
// ─────────────────────────────────────────────────────────────────────────────
class AnimatedSearchSuggestions extends StatefulWidget {
  const AnimatedSearchSuggestions({super.key});

  @override
  State<AnimatedSearchSuggestions> createState() => _AnimatedSearchSuggestionsState();
}

class _AnimatedSearchSuggestionsState extends State<AnimatedSearchSuggestions> {
  final List<String> suggestions = [
    'Nature', 'Abstract', 'Space', 'Cars', 'Amoled',
    'Mountains', 'City', 'Minimal', 'Animals', 'Neon'
  ];
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    suggestions.shuffle();
    if (!AdaptivePerformance.isLow) {
      _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % suggestions.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdaptivePerformance.isLow) {
      return Text(
        'Try searching "${suggestions[_currentIndex]}"',
        style: const TextStyle(color: Colors.white38, fontSize: 16),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: Text(
        'Try searching "${suggestions[_currentIndex]}"',
        key: ValueKey(_currentIndex),
        style: const TextStyle(color: Colors.white38, fontSize: 16),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mic bottom-sheet widget
// ─────────────────────────────────────────────────────────────────────────────
class _MicSheet extends StatefulWidget {
  final stt.SpeechToText speech;
  final ValueChanged<String> onWordsFinal;

  const _MicSheet({required this.speech, required this.onWordsFinal});

  @override
  State<_MicSheet> createState() => _MicSheetState();
}

class _MicSheetState extends State<_MicSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  String _currentWords = '';
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    
    if (!AdaptivePerformance.isLow) {
      _pulseCtrl.repeat(reverse: true);
    }

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startListening();
  }

  Future<void> _startListening() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (!widget.speech.isAvailable) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (!widget.speech.isAvailable) {
        Navigator.of(context).pop();
        return;
      }
    }

    setState(() => _listening = true);
    bool finalFired = false;
    try {
      await widget.speech.listen(
        onResult: (result) {
          if (!mounted) return;
          setState(() => _currentWords = result.recognizedWords);
          if (result.finalResult && !finalFired) {
            finalFired = true;
            widget.onWordsFinal(result.recognizedWords);
            if (mounted) Navigator.of(context).pop();
          }
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('STT listen error: $e');
      }
      if (mounted) setState(() => _listening = false);
    }
  }

  void _stopAndConfirm() {
    widget.speech.stop();
    widget.onWordsFinal(_currentWords);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    widget.speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.glassBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Listening…',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 32),
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _listening ? _pulseAnim.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldMid.withAlpha(80),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.black, size: 44),
            ),
          ),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _currentWords.isEmpty
                  ? 'Say something like "nature" or "abstract"'
                  : '"$_currentWords"',
              key: ValueKey(_currentWords),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _currentWords.isEmpty
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontSize: _currentWords.isEmpty ? 14 : 18,
                fontStyle: _currentWords.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
                fontWeight: _currentWords.isEmpty
                    ? FontWeight.normal
                    : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: _stopAndConfirm,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      color: Colors.black, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Search',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
