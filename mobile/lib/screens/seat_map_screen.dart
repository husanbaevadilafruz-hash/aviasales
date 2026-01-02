// seat_map_screen.dart - Экран карты мест самолета

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';

class SeatMapScreen extends StatefulWidget {
  final int airplaneId;
  final String airplaneModel;

  const SeatMapScreen({
    super.key,
    required this.airplaneId,
    required this.airplaneModel,
  });

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  List<Seat> _seats = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // Данные о структуре мест
  int _maxRow = 0;
  List<String> _seatLetters = [];

  @override
  void initState() {
    super.initState();
    _loadSeats();
  }

  Future<void> _loadSeats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final seats = await ApiService.getAirplaneSeats(widget.airplaneId);
      
      if (seats.isEmpty) {
        setState(() {
          _errorMessage = 'Нет мест в самолете';
          _isLoading = false;
        });
        return;
      }

      // Анализируем структуру мест
      final rowNumbers = <int>{};
      final letters = <String>{};

      for (var seat in seats) {
        // Парсим номер места: "1A" -> row=1, letter="A"
        final match = RegExp(r'^(\d+)([A-Z])$').firstMatch(seat.seatNumber);
        if (match != null) {
          rowNumbers.add(int.parse(match.group(1)!));
          letters.add(match.group(2)!);
        }
      }

      // Определяем максимальный номер ряда
      if (rowNumbers.isNotEmpty) {
        _maxRow = rowNumbers.reduce((a, b) => a > b ? a : b);
      }

      // Сортируем буквы в алфавитном порядке
      if (letters.isNotEmpty) {
        _seatLetters = letters.toList()..sort();
      }

      setState(() {
        _seats = seats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить карту мест: $e';
        _isLoading = false;
      });
    }
  }

  // Найти место по номеру
  Seat? _findSeat(int row, String letter) {
    final seatNumber = '$row$letter';
    try {
      return _seats.firstWhere((seat) => seat.seatNumber == seatNumber);
    } catch (e) {
      return null;
    }
  }

  // Цвет места в зависимости от статуса и категории
  Color _getSeatColor(Seat seat) {
    final isExtra = seat.category == 'EXTRA_LEGROOM';
    switch (seat.status) {
      case 'AVAILABLE':
        return isExtra ? Colors.purple.shade400 : Colors.green.shade400;
      case 'HELD':
        return Colors.orange.shade400;
      case 'BOOKED':
        return Colors.red.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  // Текст статуса
  String _getSeatStatusText(String status) {
    switch (status) {
      case 'AVAILABLE':
        return 'Свободно';
      case 'HELD':
        return 'Удержано';
      case 'BOOKED':
        return 'Занято';
      default:
        return 'Неизвестно';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Карта мест: ${widget.airplaneModel}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSeats,
            tooltip: 'Обновить',
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
                        onPressed: _loadSeats,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Легенда
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey.shade100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Легенда:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildLegendItem('Свободно', Colors.green.shade400),
                              _buildLegendItem('Extra legroom', Colors.purple.shade400),
                              _buildLegendItem('Удержано', Colors.orange.shade400),
                              _buildLegendItem('Занято', Colors.red.shade400),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Всего мест: ${_seats.length}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    
                    // Карта мест
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Заголовок с буквами
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 40), // Отступ для номеров рядов
                                ..._seatLetters.map((letter) => Container(
                                      width: 50,
                                      padding: const EdgeInsets.all(8),
                                      child: Center(
                                        child: Text(
                                          letter,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    )),
                              ],
                            ),
                            
                            // Ряды с местами
                            ...List.generate(_maxRow, (index) {
                              final rowNumber = index + 1;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Номер ряда
                                    SizedBox(
                                      width: 40,
                                      child: Center(
                                        child: Text(
                                          '$rowNumber',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Места в ряду
                                    ..._seatLetters.map((letter) {
                                      final seat = _findSeat(rowNumber, letter);
                                      
                                      if (seat == null) {
                                        // Пустое место (не существует)
                                        return Container(
                                          width: 50,
                                          height: 50,
                                          margin: const EdgeInsets.all(2),
                                        );
                                      }
                                      
                                      return GestureDetector(
                                        onTap: () {
                                          // Показываем детали места
                                          _showSeatDetails(seat);
                                        },
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          margin: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: _getSeatColor(seat),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: seat.category == 'EXTRA_LEGROOM'
                                                  ? Colors.purple.shade900
                                                  : Colors.grey.shade600,
                                              width: seat.category == 'EXTRA_LEGROOM' ? 2 : 1,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Center(
                                                child: Text(
                                                  seat.seatNumber,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              if (seat.category == 'EXTRA_LEGROOM')
                                                Positioned(
                                                  right: 4,
                                                  bottom: 3,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withOpacity(0.25),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'LEG',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 8,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  void _showSeatDetails(Seat seat) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Место ${seat.seatNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Статус: ${_getSeatStatusText(seat.status)}'),
            const SizedBox(height: 8),
            Text('ID самолета: ${seat.airplaneId}'),
            if (seat.heldUntil != null) ...[
              const SizedBox(height: 8),
              Text('Удержано до: ${seat.heldUntil}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}





