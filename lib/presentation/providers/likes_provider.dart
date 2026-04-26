import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/service_locator.dart';
import '../../domain/repositories/wallpaper_repository.dart';
import 'auth_provider.dart';
import 'wallpaper_provider.dart';
import 'trending_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/royal_snack_bar.dart';

class LikesState {
  final List<String> favorites;
  final List<String> feedLikes;

  const LikesState({
    this.favorites = const [],
    this.feedLikes = const [],
  });

  LikesState copyWith({
    List<String>? favorites,
    List<String>? feedLikes,
  }) {
    return LikesState(
      favorites: favorites ?? this.favorites,
      feedLikes: feedLikes ?? this.feedLikes,
    );
  }
}

final likesNotifierProvider = StateNotifierProvider<LikesNotifier, LikesState>((ref) {
  return LikesNotifier(ref);
});

// For backward compatibility and convenience
final likesProvider = Provider<List<String>>((ref) => ref.watch(likesNotifierProvider).favorites);
final feedLikesProvider = Provider<List<String>>((ref) => ref.watch(likesNotifierProvider).feedLikes);

class LikesNotifier extends StateNotifier<LikesState> {
  final Ref _ref;

  LikesNotifier(this._ref) : super(const LikesState()) {
    _ref.listen(authProvider, (previous, next) {
      if (next.user != null && next.user?.uid != previous?.user?.uid) {
        _loadLikes(next.user!.uid);
      } else if (next.user == null && next.isGuest) {
        _loadLocalLikes();
      } else if (next.user == null) {
        state = const LikesState();
      }
    });
    
    // Initial load
    final authState = _ref.read(authProvider);
    if (authState.user != null) {
      _loadLikes(authState.user!.uid);
    } else if (authState.isGuest) {
      _loadLocalLikes();
    }
  }

  Future<void> _loadLikes(String userId) async {
    try {
      final doc = await sl<FirebaseFirestore>().collection('users').doc(userId).get();
      if (doc.exists) {
        final List<dynamic> liked = doc.data()?['liked_wallpapers'] ?? [];
        final List<dynamic> feedLiked = doc.data()?['feed_likes'] ?? [];
        state = LikesState(
          favorites: liked.cast<String>(),
          feedLikes: feedLiked.cast<String>(),
        );
      }
    } catch (_) {
      // Handle error
    }
  }

  static const _guestLikesKey = 'favorite_wallpaper_ids';
  static const _guestFeedLikesKey = 'feed_likes_ids';

  Future<void> _loadLocalLikes() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> liked = prefs.getStringList(_guestLikesKey) ?? [];
    final List<String> feedLiked = prefs.getStringList(_guestFeedLikesKey) ?? [];
    state = LikesState(
      favorites: liked,
      feedLikes: feedLiked,
    );
  }

  final Set<String> _togglingIds = {};

  Future<void> toggleLike(String wallpaperId, {bool isFavorite = true}) async {
    if (_togglingIds.contains(wallpaperId)) return;

    final authState = _ref.read(authProvider);
    final user = authState.user;

    _togglingIds.add(wallpaperId);
    
    final currentList = isFavorite ? state.favorites : state.feedLikes;
    final wasLiked = currentList.contains(wallpaperId);

    // 1. Optimistic UI Update
    if (wasLiked) {
      final newList = currentList.where((id) => id != wallpaperId).toList();
      state = isFavorite ? state.copyWith(favorites: newList) : state.copyWith(feedLikes: newList);
      _ref.read(wallpaperProvider.notifier).incrementLikesLocally(wallpaperId, -1);
      _ref.read(trendingProvider.notifier).updateLikeCount(wallpaperId, -1);
    } else {
      final newList = [...currentList, wallpaperId];
      state = isFavorite ? state.copyWith(favorites: newList) : state.copyWith(feedLikes: newList);
      _ref.read(wallpaperProvider.notifier).incrementLikesLocally(wallpaperId, 1);
      _ref.read(trendingProvider.notifier).updateLikeCount(wallpaperId, 1);
    }

    if (user == null) {
      // 2a. Guest Update (Local Only)
      final prefs = await SharedPreferences.getInstance();
      if (isFavorite) {
        await prefs.setStringList(_guestLikesKey, state.favorites);
      } else {
        await prefs.setStringList(_guestFeedLikesKey, state.feedLikes);
      }
      
      // Also notify the server anonymously to update global count
      final repo = sl<WallpaperRepository>();
      await repo.toggleLikeAnonymous(wallpaperId, !wasLiked);
      
      _togglingIds.remove(wallpaperId);
      return;
    }

    // 2b. Remote Update (Authenticated Users)
    final repo = sl<WallpaperRepository>();
    final result = await repo.toggleLike(user.uid, wallpaperId, isFavorite: isFavorite);

    result.fold(
      (failure) {
        // Rollback on absolute failure (rare now with best-effort)
        if (wasLiked) {
          final newList = [...currentList, wallpaperId];
          state = isFavorite ? state.copyWith(favorites: newList) : state.copyWith(feedLikes: newList);
          _ref.read(wallpaperProvider.notifier).incrementLikesLocally(wallpaperId, 1);
          _ref.read(trendingProvider.notifier).updateLikeCount(wallpaperId, 1);
        } else {
          final newList = currentList.where((id) => id != wallpaperId).toList();
          state = isFavorite ? state.copyWith(favorites: newList) : state.copyWith(feedLikes: newList);
          _ref.read(wallpaperProvider.notifier).incrementLikesLocally(wallpaperId, -1);
          _ref.read(trendingProvider.notifier).updateLikeCount(wallpaperId, -1);
        }
        
        RoyalSnackBar.show(null, 'Could not update like: ${failure.message}', type: SnackBarType.error);
      },
      (isLikedServer) {
        // Sync with server result
        final locallyLiked = (isFavorite ? state.favorites : state.feedLikes).contains(wallpaperId);
        if (isLikedServer && !locallyLiked) {
          final newList = [...(isFavorite ? state.favorites : state.feedLikes), wallpaperId];
          state = isFavorite ? state.copyWith(favorites: newList) : state.copyWith(feedLikes: newList);
          _ref.read(wallpaperProvider.notifier).incrementLikesLocally(wallpaperId, 1);
          _ref.read(trendingProvider.notifier).updateLikeCount(wallpaperId, 1);
        } else if (!isLikedServer && locallyLiked) {
          final newList = (isFavorite ? state.favorites : state.feedLikes).where((id) => id != wallpaperId).toList();
          state = isFavorite ? state.copyWith(favorites: newList) : state.copyWith(feedLikes: newList);
          _ref.read(wallpaperProvider.notifier).incrementLikesLocally(wallpaperId, -1);
          _ref.read(trendingProvider.notifier).updateLikeCount(wallpaperId, -1);
        }
      },
    );

    _togglingIds.remove(wallpaperId);
  }

  bool isFavorite(String wallpaperId) {
    return state.favorites.contains(wallpaperId);
  }

  bool isFeedLiked(String wallpaperId) {
    return state.feedLikes.contains(wallpaperId);
  }
}
