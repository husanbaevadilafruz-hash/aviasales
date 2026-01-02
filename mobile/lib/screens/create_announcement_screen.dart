// create_announcement_screen.dart - Экран создания объявления (для STAFF)

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  List<Flight> _flights = [];
  Flight? _selectedFlight;
  bool _isLoading = false;
  bool _isLoadingFlights = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFlights();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadFlights() async {
    setState(() {
      _isLoadingFlights = true;
    });

    try {
      // Получаем все рейсы через поиск (сотрудник видит все рейсы)
      final flights = await ApiService.searchFlights(showAll: true);
      setState(() {
        _flights = flights;
        _isLoadingFlights = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить рейсы';
        _isLoadingFlights = false;
      });
    }
  }

  Future<void> _createAnnouncement() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Заполните все поля';
      });
      return;
    }

    if (_selectedFlight == null) {
      setState(() {
        _errorMessage = 'Выберите рейс';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Проверяем что flightId не null перед отправкой
      final flightId = _selectedFlight!.id;
      if (flightId == null) {
        setState(() {
          _errorMessage = 'Ошибка: ID рейса не может быть пустым';
          _isLoading = false;
        });
        return;
      }
      
      // ИСПРАВЛЕНО: Используем createNotification вместо createAnnouncement
      // Notification - для уведомлений пассажирам конкретного рейса
      // Announcement - для общих объявлений всем пассажирам
      await ApiService.createNotification(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        flightId: flightId,  // Отправляем всем пассажирам этого рейса
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Уведомление успешно отправлено всем пассажирам рейса!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
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
        title: const Text('Создать объявление'),
      ),
      body: _isLoadingFlights
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Выбор рейса
                  DropdownButtonFormField<Flight>(
                    value: _selectedFlight,
                    decoration: const InputDecoration(
                      labelText: 'Рейс *',
                      hintText: 'Выберите рейс',
                      prefixIcon: Icon(Icons.flight),
                      border: OutlineInputBorder(),
                    ),
                    items: _flights.map((flight) {
                      return DropdownMenuItem<Flight>(
                        value: flight,
                        child: Text(
                          '${flight.flightNumber} - ${flight.departureAirport.code} → ${flight.arrivalAirport.code}',
                        ),
                      );
                    }).toList(),
                    onChanged: (Flight? flight) {
                      setState(() {
                        _selectedFlight = flight;
                        _errorMessage = null;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок *',
                      hintText: 'Например: Задержка рейса SU100',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Содержание *',
                      hintText: 'Текст объявления...',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 8,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    '* Объявление будет отправлено всем пассажирам выбранного рейса',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createAnnouncement,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Создать объявление'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
