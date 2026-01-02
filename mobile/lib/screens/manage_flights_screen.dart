// manage_flights_screen.dart - Экран управления рейсами (для STAFF)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class ManageFlightsScreen extends StatefulWidget {
  const ManageFlightsScreen({super.key});

  @override
  State<ManageFlightsScreen> createState() => _ManageFlightsScreenState();
}

class _ManageFlightsScreenState extends State<ManageFlightsScreen> {
  List<Flight> _flights = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFlights();
  }

  Future<void> _loadFlights() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем все рейсы через поиск (сотрудник видит все рейсы)
      final flights = await ApiService.searchFlights(showAll: true);
      setState(() {
        _flights = flights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить рейсы';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateFlightStatus(Flight flight, String newStatus, {DateTime? newDepartureTime, DateTime? newArrivalTime, String? newGate}) async {
    try {
      await ApiService.updateFlightStatus(
        flightId: flight.id,
        status: newStatus,
        departureTime: newDepartureTime,
        arrivalTime: newArrivalTime,
        gate: newGate,
      );

      if (mounted) {
        String message = 'Рейс обновлён';
        if (newGate != null) {
          message = 'Gate изменён на: $newGate';
        } else if (newDepartureTime != null) {
          message = 'Статус рейса изменён на: $newStatus\nНовое время вылета: ${DateFormat('dd.MM.yyyy HH:mm').format(newDepartureTime)}';
        } else {
          message = 'Статус рейса изменён на: $newStatus';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
        _loadFlights(); // Обновляем список
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusDialog(Flight flight) {
    final statuses = [
      'SCHEDULED',
      'DELAYED',
      'BOARDING',
      'DEPARTED',
      'ARRIVED',
      'CANCELLED',
      'COMPLETED',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить статус рейса ${flight.flightNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((status) {
            return ListTile(
              title: Text(status),
              trailing: flight.status == status
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(context);
                if (status == 'DELAYED') {
                  // Для DELAYED показываем диалог выбора нового времени
                  _showDelayedTimeDialog(flight);
                } else {
                  _updateFlightStatus(flight, status);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showGateDialog(Flight flight) {
    final gateController = TextEditingController(text: flight.gate);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить Gate для ${flight.flightNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Текущий Gate: ${flight.gate.isNotEmpty ? flight.gate : "Не указан"}'),
            const SizedBox(height: 16),
            TextField(
              controller: gateController,
              decoration: const InputDecoration(
                labelText: 'Новый Gate',
                hintText: 'Например: A12, B5',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final newGate = gateController.text.trim();
              Navigator.pop(context);
              if (newGate.isNotEmpty && newGate != flight.gate) {
                _updateFlightStatus(flight, flight.status, newGate: newGate);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showDelayedTimeDialog(Flight flight) {
    DateTime newDepartureTime = flight.departureTime;
    DateTime newArrivalTime = flight.arrivalTime;
    final flightDuration = flight.arrivalTime.difference(flight.departureTime);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Задержка рейса'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Текущее время вылета: ${DateFormat('dd.MM.yyyy HH:mm').format(flight.departureTime)}'),
              const SizedBox(height: 16),
              const Text('Новое время вылета:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(DateFormat('dd.MM.yyyy').format(newDepartureTime)),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: newDepartureTime,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            newDepartureTime = DateTime(
                              date.year, date.month, date.day,
                              newDepartureTime.hour, newDepartureTime.minute,
                            );
                            // Автоматически обновляем время прилёта
                            newArrivalTime = newDepartureTime.add(flightDuration);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(DateFormat('HH:mm').format(newDepartureTime)),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(newDepartureTime),
                        );
                        if (time != null) {
                          setDialogState(() {
                            newDepartureTime = DateTime(
                              newDepartureTime.year, newDepartureTime.month, newDepartureTime.day,
                              time.hour, time.minute,
                            );
                            // Автоматически обновляем время прилёта
                            newArrivalTime = newDepartureTime.add(flightDuration);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Новое время прилёта: ${DateFormat('dd.MM.yyyy HH:mm').format(newArrivalTime)}',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _updateFlightStatus(
                  flight,
                  'DELAYED',
                  newDepartureTime: newDepartureTime,
                  newArrivalTime: newArrivalTime,
                );
              },
              child: const Text('Подтвердить задержку'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление рейсами'),
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
                        onPressed: _loadFlights,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : _flights.isEmpty
                  ? const Center(child: Text('Нет рейсов'))
                  : RefreshIndicator(
                      onRefresh: _loadFlights,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _flights.length,
                        itemBuilder: (context, index) {
                          final flight = _flights[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListTile(
                              leading: const Icon(Icons.flight, size: 40),
                              title: Text(
                                '${flight.departureAirport.code} → ${flight.arrivalAirport.code}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Рейс: ${flight.flightNumber}'),
                                  Text(
                                    '${DateFormat('dd.MM.yyyy HH:mm').format(flight.departureTime)} - ${DateFormat('HH:mm').format(flight.arrivalTime)}',
                                  ),
                                  Text('Статус: ${flight.status}'),
                                  Text(
                                    'Gate: ${flight.gate.isNotEmpty ? flight.gate : "Не указан"}',
                                    style: TextStyle(
                                      color: flight.gate.isNotEmpty ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.door_front_door, color: Colors.blue),
                                    tooltip: 'Изменить Gate',
                                    onPressed: () => _showGateDialog(flight),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    tooltip: 'Изменить статус',
                                    onPressed: () => _showStatusDialog(flight),
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







