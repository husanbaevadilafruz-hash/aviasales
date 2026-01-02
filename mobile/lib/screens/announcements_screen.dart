// announcements_screen.dart - Экран объявлений

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  List<Announcement> _announcements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final announcements = await ApiService.getAnnouncements();
      setState(() {
        _announcements = announcements;
        _isLoading = false;
        _errorMessage = null; // Очищаем ошибку при успешной загрузке
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить объявления';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Объявления'),
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
                        onPressed: _loadAnnouncements,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : _announcements.isEmpty
                  ? const Center(
                      child: Text('Нет объявлений'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAnnouncements,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _announcements.length,
                        itemBuilder: (context, index) {
                          final announcement = _announcements[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.announcement,
                                        color: Colors.orange,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          announcement.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    announcement.content,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm').format(
                                      announcement.createdAt,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

