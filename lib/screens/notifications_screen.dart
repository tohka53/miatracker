// lib/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/in_app_notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: InAppNotificationService.notificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification['is_read'] as bool;
              final createdAt = DateTime.parse(notification['created_at']);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isRead ? Colors.grey : Colors.blue,
                  child: Icon(
                    _getIconForType(notification['type']),
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  notification['title'],
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification['message']),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                tileColor: isRead ? null : Colors.blue.withOpacity(0.1),
                onTap: () async {
                  if (!isRead) {
                    await InAppNotificationService.markAsRead(notification['id']);
                  }

                  // Manejar navegación según el tipo
                  _handleNotificationTap(context, notification);
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'restock_approved':
        return Icons.check_circle;
      case 'restock_rejected':
        return Icons.cancel;
      case 'order_completed':
        return Icons.done_all;
      case 'low_stock':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  void _handleNotificationTap(BuildContext context, Map<String, dynamic> notification) {
    final data = notification['data'] as Map<String, dynamic>?;

    if (data == null) return;

    final type = notification['type'] as String;

    switch (type) {
      case 'restock_approved':
        final requestId = data['request_id'];
        Navigator.pushNamed(
          context,
          '/restock-details',
          arguments: requestId,
        );
        break;
    // Agregar más casos según necesites
    }
  }
}