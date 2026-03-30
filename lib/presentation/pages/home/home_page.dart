import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../domain/entities/wallpaper_entity.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallpaper_provider.dart';
import '../../widgets/wallpaper_card.dart';
import '../../widgets/diamond_loader.dart';
import 'wallpaper_search_delegate.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceWords = '';
  // Track whether we've already shown the in-app rationale dialog
  bool _permissionRationaleShown = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(
        () => ref.read(wallpaperProvider.notifier).loadWallpapers());
    // Do NOT auto-init speech on startup – we request permission only on demand.
  }

  // ─── Permission helpers ───────────────────────────────────────

  /// Shows an in-app rationale dialog BEFORE the OS system prompt.
  /// Returns true if the user tapped "Allow" (proceed to OS prompt).
  Future<bool> _showRationaleDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.amber),
            SizedBox(width: 10),
            Text('Voice Search',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Royal Pixels needs microphone access to let you search wallpapers by voice.\n\n'
          'Tap "Allow" to grant microphone permission.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Shows «Open Settings» dialog when permission is permanently denied.
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.mic_off, color: Colors.amber),
            SizedBox(width: 10),
            Text('Microphone Blocked',
                style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Microphone permission was denied.\n\n'
          'Go to Settings → App Permissions → Microphone and enable access for Royal Pixels.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Requests microphone permission on-demand.
  /// Shows our rationale dialog first if this is the first request.
  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.status;

    // Already granted – great, proceed.
    if (status.isGranted) return true;

    // Permanently denied – cannot show system prompt anymore, go to Settings.
    if (status.isPermanentlyDenied) {
      if (mounted) _showSettingsDialog();
      return false;
    }

    // Show our in-app rationale before the OS system prompt (first-time ask).
    if (!_permissionRationaleShown) {
      _permissionRationaleShown = true;
      if (!mounted) return false;
      final proceed = await _showRationaleDialog();
      if (!proceed) return false;
    }

    // Trigger the actual OS permission request.
    final result = await Permission.microphone.request();
    if (result.isGranted) return true;

    if (result.isPermanentlyDenied && mounted) _showSettingsDialog();
    return false;
  }

  /// Initialises speech_to_text after confirming microphone permission.
  Future<bool> _initSpeech() async {
    final granted = await _requestMicPermission();
    if (!granted) return false;

    // If already initialised, skip re-init to avoid issues.
    if (_speechAvailable) return true;

    bool ok = false;
    try {
      ok = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          debugPrint('STT error: ${error.errorMsg}');
          if (mounted) setState(() => _isListening = false);
        },
        debugLogging: true,
      );
    } catch (e) {
      debugPrint('STT init exception: $e');
      ok = false;
    }

    if (mounted) setState(() => _speechAvailable = ok);
    return ok;
  }

  /// Opens an animated bottom-sheet microphone UI, listens, then
  /// opens the search delegate pre-filled with the recognised words.
  Future<void> _startVoiceSearch() async {
    // Always try to init/re-check permission when the user taps mic.
    final ready = await _initSpeech();

    if (!ready || !_speech.isAvailable) {
      // Permission denied or STT unavailable – already shown dialog.
      return;
    }

    setState(() {
      _voiceWords = '';
      _isListening = false;
    });

    // Use a local variable to capture the recognised words reliably —
    // avoids setState-timing races where _voiceWords might not be committed
    // by the time the code after await showModalBottomSheet runs.
    String recognisedWords = '';

    // Show the mic bottom-sheet
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => _MicSheet(
        speech: _speech,
        onWordsFinal: (words) {
          recognisedWords = words; // capture immediately, no setState race
          if (mounted) {
            setState(() {
              _voiceWords = words;
              _isListening = false;
            });
          }
        },
      ),
    );

    if (mounted) setState(() => _isListening = false);

    // When the sheet is dismissed, open search if we got recognised words.
    // Wait for bottom-sheet dismiss animation to fully complete before pushing
    // search — chaining navigations without this can silently fail.
    if (!mounted) return;
    final query = recognisedWords.trim().isNotEmpty
        ? recognisedWords.trim()
        : _voiceWords.trim();

    if (query.isNotEmpty) {
      // Small pause so the modal-route exit animation finishes.
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      final wallpaperState = ref.read(wallpaperProvider);
      final allWallpapers = [
        ...wallpaperState.freeWallpapers,
        ...wallpaperState.premiumWallpapers,
      ];
      showSearch(
        context: context,
        delegate: WallpaperSearchDelegate(allWallpapers),
        query: query,
      );
    }
  }

  void _openSearch() {
    final wallpaperState = ref.read(wallpaperProvider);
    final allWallpapers = [
      ...wallpaperState.freeWallpapers,
      ...wallpaperState.premiumWallpapers,
    ];
    showSearch(
      context: context,
      delegate: WallpaperSearchDelegate(allWallpapers),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallpaperState = ref.watch(wallpaperProvider);
    final userState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Royal Pixels'),
        actions: [
          // ── Mic button ──
          IconButton(
            tooltip: 'Voice Search',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                key: ValueKey(_isListening),
                color: _isListening ? Colors.amber : Colors.white,
              ),
            ),
            onPressed: _startVoiceSearch,
          ),
          // ── Search button ──
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Free'),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.diamond, size: 16),
                  SizedBox(width: 6),
                  Text('Premium'),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF121212),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.diamond, size: 40, color: Colors.amber),
                  const Spacer(),
                  Text(
                    userState.user?.name ?? 'Guest User',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    userState.user?.email ?? '',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: Colors.amber),
              title: const Text('Home'),
              onTap: () => context.pop(),
            ),
            ListTile(
              leading: const Icon(Icons.favorite, color: Colors.amber),
              title: const Text('My Wallpapers',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/my-wallpapers');
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.info_outline_rounded, color: Colors.amber),
              title:
                  const Text('About', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/about');
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white70),
              title: const Text('Logout',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.of(context).pop();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
      body: wallpaperState.isLoading
          ? const Center(
              child: DiamondLoader())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(wallpaperState.freeWallpapers),
                _buildGrid(wallpaperState.premiumWallpapers),
              ],
            ),
    );
  }

  Widget _buildGrid(List<WallpaperEntity> wallpapers) {
    if (wallpapers.isEmpty) {
      return const Center(
          child:
              Text('No Wallpapers Found', style: TextStyle(color: Colors.white)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: wallpapers.length,
      itemBuilder: (context, index) {
        final wp = wallpapers[index];
        return WallpaperCard(
          wallpaper: wp,
          onTap: () => context.push('/detail', extra: wp),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Mic bottom-sheet widget with animated pulsing mic
// ─────────────────────────────────────────────────────────────
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
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _startListening();
  }

  Future<void> _startListening() async {
    // Give the bottom-sheet time to fully mount before starting the engine.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // If STT reports not available after the delay, close gracefully.
    if (!widget.speech.isAvailable) {
      // Try one more time — the engine sometimes needs a moment after init.
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
        // No localeId → use device's default language (avoids silent failures
        // on non-en_US locales and on devices without en_US speech model).
      );
    } catch (e) {
      debugPrint('STT listen error: $e');
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
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Listening…',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 32),
          // Pulsing mic
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
                gradient: RadialGradient(
                  colors: [
                    Colors.amber.withAlpha(230),
                    Colors.orange.shade700.withAlpha(180),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withAlpha(120),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 44),
            ),
          ),
          const SizedBox(height: 28),
          // Live transcript
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _currentWords.isEmpty
                  ? 'Say something like "nature" or "abstract"'
                  : '"$_currentWords"',
              key: ValueKey(_currentWords),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _currentWords.isEmpty ? Colors.white38 : Colors.white,
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
          // Done button
          ElevatedButton.icon(
            onPressed: _stopAndConfirm,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
