// all_notifications_screen.dart - Экран просмотра всех уведомлений (для STAFF)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class AllNotificationsScreen extends StatefulWidget {
  const AllNotificationsScreen({super.key});

  @override
  State<AllNotificationsScreen> createState() => _AllNotificationsScreenState();
}

class _AllNotificationsScreenState extends State<AllNotificationsScreen> {
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
      final notifications = await ApiService.getAllNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все уведомления'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                      child: Text(
                        'Уведомления отсутствуют',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        itemCount: _notifications.length,
                        padding: const EdgeInsets.all(8.0),
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: ListTile(
                              leading: Icon(
                                notification.isRead
                                    ? Icons.notifications
                                    : Icons.notifications_active,
                                color: notification.isRead
                                    ? Colors.grey
                                    : Colors.blue,
                              ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(notification.content),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Получатель: ID ${notification.userId}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (notification.flightId != null)
                                    Text(
                                      'Рейс: ID ${notification.flightId}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  Text(
                                    DateFormat('dd.MM.yyyy HH:mm')
                                        .format(notification.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

