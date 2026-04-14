import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/leaderboard_provider.dart';
import '../../../domain/entities/user_entity.dart';

class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboards'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white60,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),
          tabs: const [
            Tab(text: '🥇 Collectors'),
            Tab(text: '💰 Supporters'),
            Tab(text: '⚡ Active'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeaderboardTab(
            provider: topCollectorsProvider, 
            title: 'Top Collectors',
            subtitleExtractor: (user) => '${user.ownedWallpaperCount} Wallpapers',
          ),
          _LeaderboardTab(
            provider: topSupportersProvider, 
            title: 'Top Supporters',
            subtitleExtractor: (user) => '₹${user.totalSpent.toStringAsFixed(0)} Spent',
          ),
          _LeaderboardTab(
            provider: activeUsersProvider, 
            title: 'Most Active',
            subtitleExtractor: (user) => '${user.activityScore} Points',
          ),
        ],
      ),
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  final FutureProvider<List<UserEntity>> provider;
  final String title;
  final String Function(UserEntity) subtitleExtractor;

  const _LeaderboardTab({
    required this.provider,
    required this.title,
    required this.subtitleExtractor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);

    return state.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
      error: (err, stack) => Center(
        child: Text(
          'Failed to load leaderboard.\n$err',
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      ),
      data: (users) {
        if (users.isEmpty) {
          return const Center(
            child: Text(
              'No users found yet.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _LeaderboardTile(
              rank: index + 1,
              user: user,
              subtitle: subtitleExtractor(user),
            );
          },
        );
      },
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final UserEntity user;
  final String subtitle;

  const _LeaderboardTile({
    required this.rank,
    required this.user,
    required this.subtitle,
  });

  Widget _buildRankIcon() {
    if (rank == 1) {
      return const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 36); // Gold
    } else if (rank == 2) {
      return const Icon(Icons.workspace_premium, color: Color(0xFFC0C0C0), size: 36); // Silver
    } else if (rank == 3) {
      return const Icon(Icons.workspace_premium, color: Color(0xFFCD7F32), size: 36); // Bronze
    }
    
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white12,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$rank',
        style: const TextStyle(
          color: Colors.white70, 
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTop3 = rank <= 3;
    final borderColor = rank == 1 ? Colors.amber.withAlpha(127) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: _buildRankIcon(),
        title: Text(
          user.name.isEmpty ? 'Anonymous' : user.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isTop3 ? FontWeight.bold : FontWeight.w500,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
        ),
        trailing: CircleAvatar(
          backgroundColor: Colors.white12,
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
