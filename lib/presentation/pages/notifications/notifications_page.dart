import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../providers/notification_provider.dart';
import '../../../domain/entities/notification_type.dart';
import '../../../domain/entities/notification_item.dart';
import '../../../core/utils/safe_tap.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'NOTIFICATIONS',
          style: TextStyle(
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifications) => notifications.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.amber),
                    onPressed: () => _showClearAllConfirm(context, ref),
                    tooltip: 'Clear All',
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(notificationProvider),
            color: Colors.amber,
            backgroundColor: Colors.grey[900],
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationItemCard(notification: notification)
                    .animate(delay: (index * 50).ms)
                    .fadeIn()
                    .slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Error loading notifications: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_outlined, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 16),
          const Text(
            'Nothing to see here',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll notify you when something important happens.',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }

  void _showClearAllConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Clear All Notifications?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              SafeTap.run('notifications_clear_all', () {
                ref.read(notificationProvider.notifier).clearAll();
                Navigator.pop(context);
              });
            },
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }
}

class _NotificationItemCard extends ConsumerWidget {
  final NotificationItem notification;

  const _NotificationItemCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.isRead ? Colors.grey[900]!.withValues(alpha: 0.5) : Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isRead ? Colors.transparent : Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          SafeTap.run('notification_tap_${notification.id}', () {
            if (!notification.isRead) {
              ref.read(notificationProvider.notifier).markAsRead(notification.id);
            }
            // Deep link logic could go here
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeading(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            color: notification.isRead ? Colors.grey[300] : Colors.white,
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _formatDate(notification.timestamp),
                          style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: notification.isRead ? Colors.grey[500] : Colors.grey[400],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 2),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                 .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 1.seconds)
                 .then()
                 .scale(begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    if (notification.imageUrl != null && notification.imageUrl!.isNotEmpty) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              notification.imageUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildTypeIcon(),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: _buildMiniTypeIcon(),
            ),
          ),
        ],
      );
    }
    return _buildTypeIcon();
  }

  Widget _buildMiniTypeIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.download:
        iconData = Icons.file_download_outlined;
        iconColor = Colors.blue;
        break;
      case NotificationType.purchase:
        iconData = Icons.shopping_bag_outlined;
        iconColor = Colors.green;
        break;
      case NotificationType.reward:
        iconData = Icons.stars_rounded;
        iconColor = Colors.amber;
        break;
      case NotificationType.content:
        iconData = Icons.new_releases_outlined;
        iconColor = Colors.purple;
        break;
      default:
        iconData = Icons.notifications_outlined;
        iconColor = Colors.grey;
    }

    return Icon(iconData, color: iconColor, size: 10);
  }

  Widget _buildTypeIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.download:
        iconData = Icons.file_download_outlined;
        iconColor = Colors.blue;
        break;
      case NotificationType.purchase:
        iconData = Icons.shopping_bag_outlined;
        iconColor = Colors.green;
        break;
      case NotificationType.reward:
        iconData = Icons.stars_rounded;
        iconColor = Colors.amber;
        break;
      case NotificationType.content:
        iconData = Icons.new_releases_outlined;
        iconColor = Colors.purple;
        break;
      case NotificationType.update:
        iconData = Icons.system_update_alt_outlined;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.notifications_outlined;
        iconColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: iconColor, size: 22),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
