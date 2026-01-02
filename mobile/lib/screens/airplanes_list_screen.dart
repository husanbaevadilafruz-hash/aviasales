// airplanes_list_screen.dart - Экран списка самолетов (для STAFF)

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import 'seat_map_screen.dart';

class AirplanesListScreen extends StatefulWidget {
  const AirplanesListScreen({super.key});

  @override
  State<AirplanesListScreen> createState() => _AirplanesListScreenState();
}

class _AirplanesListScreenState extends State<AirplanesListScreen> {
  List<Airplane> _airplanes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAirplanes();
  }

  Future<void> _loadAirplanes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final airplanes = await ApiService.getAirplanes();
      setState(() {
        _airplanes = airplanes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить самолеты';
        _isLoading = false;
      });
    }
  }

  // Вычисляем количество рядов и мест в ряду из номеров мест
  Future<Map<String, int>> _calculateSeatInfo(int airplaneId) async {
    try {
      final seats = await ApiService.getAirplaneSeats(airplaneId);
      if (seats.isEmpty) {
        return {'rows': 0, 'seatsPerRow': 0};
      }
      
      // Парсим номера мест (например, "1A", "12B", "30C")
      // Извлекаем максимальный номер ряда и уникальные буквы
      final rowNumbers = <int>{};
      final seatLetters = <String>{};
      
      for (var seat in seats) {
        // Парсим seat_number: "1A" -> row=1, letter="A"
        final match = RegExp(r'^(\d+)([A-Z])$').firstMatch(seat.seatNumber);
        if (match != null) {
          rowNumbers.add(int.parse(match.group(1)!));
          seatLetters.add(match.group(2)!);
        }
      }
      
      if (rowNumbers.isEmpty || seatLetters.isEmpty) {
        return {'rows': 0, 'seatsPerRow': 0};
      }
      
      final maxRow = rowNumbers.reduce((a, b) => a > b ? a : b);
      final seatsPerRow = seatLetters.length;
      
      return {'rows': maxRow, 'seatsPerRow': seatsPerRow};
    } catch (e) {
      // Если не удалось получить места, возвращаем 0
      return {'rows': 0, 'seatsPerRow': 0};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список самолетов'),
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
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadAirplanes,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _airplanes.isEmpty
                  ? const Center(
                      child: Text('Нет самолетов в системе'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadAirplanes,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _airplanes.length,
                        itemBuilder: (context, index) {
                          final airplane = _airplanes[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.airplanemode_active,
                                        size: 32,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          airplane.model,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Удалить самолёт?'),
                                              content: const Text(
                                                  'Это действие отменит все будущие рейсы и бронирования, связанные с этим самолётом.\n\nВы уверены?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, false),
                                                  child: const Text('Отмена'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context, true),
                                                  child: const Text(
                                                    'Удалить',
                                                    style: TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true && mounted) {
                                            try {
                                              await ApiService.deleteAirplane(airplane.id);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Самолёт удалён')),
                                                );
                                                _loadAirplanes();
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Ошибка: $e')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      const Icon(Icons.event_seat, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Всего мест: ${airplane.totalSeats}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  FutureBuilder<Map<String, int>>(
                                    future: _calculateSeatInfo(airplane.id),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const Row(
                                          children: [
                                            Icon(Icons.view_module, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Загрузка...',
                                              style: TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        );
                                      }
                                      
                                      final seatInfo = snapshot.data ?? {'rows': 0, 'seatsPerRow': 0};
                                      
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.view_module, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                seatInfo['rows']! > 0 
                                                    ? 'Рядов: ${seatInfo['rows']}'
                                                    : 'Рядов: не определено',
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.grid_view, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                seatInfo['seatsPerRow']! > 0
                                                    ? 'Мест в ряду: ${seatInfo['seatsPerRow']}'
                                                    : 'Мест в ряду: не определено',
                                                style: const TextStyle(fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SeatMapScreen(
                                              airplaneId: airplane.id,
                                              airplaneModel: airplane.model,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.map),
                                      label: const Text('Посмотреть карту мест'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
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

