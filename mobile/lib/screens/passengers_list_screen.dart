// passengers_list_screen.dart - Экран списка пассажиров (для STAFF)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class PassengersListScreen extends StatefulWidget {
  const PassengersListScreen({super.key});

  @override
  State<PassengersListScreen> createState() => _PassengersListScreenState();
}

class _PassengersListScreenState extends State<PassengersListScreen> {
  List<PassengerInfo> _passengers = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPassengers();
  }

  Future<void> _loadPassengers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final passengers = await ApiService.getAllPassengers();
      setState(() {
        _passengers = passengers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить пассажиров';
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список пассажиров'),
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
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPassengers,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : _passengers.isEmpty
                  ? const Center(child: Text('Нет зарегистрированных пассажиров'))
                  : RefreshIndicator(
                      onRefresh: _loadPassengers,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _passengers.length,
                        itemBuilder: (context, index) {
                          final passenger = _passengers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: const Icon(Icons.person, size: 40),
                              title: Text(
                                '${passenger.firstName} ${passenger.lastName}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Email: ${passenger.email}'),
                                  Text(
                                    'Дата рождения: ${DateFormat('dd.MM.yyyy').format(passenger.dateOfBirth)}',
                                  ),
                                  Text('Паспорт: ${passenger.passportNumber}'),
                                  if (passenger.phone != null)
                                    Text('Телефон: ${passenger.phone}'),
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

