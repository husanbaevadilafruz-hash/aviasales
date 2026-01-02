// notifications_screen.dart - Экран уведомлений для пассажиров

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final notifications = await ApiService.getMyNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить уведомления: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'У вас пока нет уведомлений',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
                    ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.isRead ? Colors.grey : Colors.blue,
          child: Icon(
            _getNotificationIcon(notification.title),
            color: Colors.white,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.content),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy, HH:mm').format(notification.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  IconData _getNotificationIcon(String title) {
    if (title.contains('посадка') || title.contains('BOARDING')) {
      return Icons.airline_seat_recline_normal;
    } else if (title.contains('вылетел') || title.contains('DEPARTED')) {
      return Icons.flight_takeoff;
    } else if (title.contains('прибыл') || title.contains('ARRIVED')) {
      return Icons.flight_land;
    } else if (title.contains('отменён') || title.contains('CANCELLED')) {
      return Icons.cancel;
    } else if (title.contains('задержан') || title.contains('DELAYED')) {
      return Icons.schedule;
    }
    return Icons.notifications;
  }
}

