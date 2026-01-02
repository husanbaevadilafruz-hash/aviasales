// flight_details_screen.dart - Детали рейса и выбор места

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import 'booking_screen.dart';

class FlightDetailsScreen extends StatefulWidget {
  final Flight flight;

  const FlightDetailsScreen({super.key, required this.flight});

  @override
  State<FlightDetailsScreen> createState() => _FlightDetailsScreenState();
}

class _FlightDetailsScreenState extends State<FlightDetailsScreen> {
  SeatMap? _seatMap;
  List<Seat> _selectedSeats = [];
  Map<int, PassengerPerSeat> _passengerData = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSeatMap();
  }

  Future<void> _loadSeatMap() async {
    try {
      final seatMap = await ApiService.getSeatMap(widget.flight.id);
      setState(() {
        _seatMap = seatMap;
        _isLoading = false;
        _errorMessage = null; // Очищаем ошибку при успешной загрузке
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить карту мест';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectSeat(Seat seat) async {
    if (seat.isBooked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Место уже забронировано')),
      );
      return;
    }

    if (seat.isHeld) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Место временно удержано')),
      );
      return;
    }

    // Если место уже выбрано, просто удаляем его
    if (_selectedSeats.contains(seat)) {
      setState(() {
        _selectedSeats.remove(seat);
        _passengerData.remove(seat.id);
      });
      return;
    }

    // Иначе запрашиваем данные пассажира
    final passenger = await _showPassengerDataDialog(seat);
    if (passenger == null) return; // Пользователь отменил ввод

    try {
      await ApiService.holdSeat(seat.id);
      setState(() {
        _selectedSeats.add(seat);
        _passengerData[seat.id] = passenger;
      });
      _loadSeatMap(); // Обновляем карту мест
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<PassengerPerSeat?> _showPassengerDataDialog(Seat seat) async {
    final nameController = TextEditingController();
    final docController = TextEditingController();
    DateTime? birthDate;

    // Пытаемся предзаполнить данными профиля, если это первое выбираемое место
    if (_selectedSeats.isEmpty) {
        try {
            final profile = await ApiService.getProfile();
            if (profile != null) {
                nameController.text = '${profile.firstName} ${profile.lastName}';
                docController.text = profile.passportNumber;
                birthDate = profile.dateOfBirth;
            }
        } catch (_) {}
    }

    return showDialog<PassengerPerSeat>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Данные пассажира (Место ${seat.seatNumber})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'ФИО полностью',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: birthDate ?? DateTime(1990, 1, 1),
                      firstDate: DateTime(1900, 1, 1),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() {
                        birthDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дата рождения',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      birthDate != null
                          ? DateFormat('dd.MM.yyyy').format(birthDate!)
                          : 'Выберите дату',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: docController,
                  decoration: const InputDecoration(
                    labelText: 'Номер паспорта',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty || docController.text.trim().isEmpty || birthDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Заполните все поля')));
                    return;
                }
                Navigator.pop(context, PassengerPerSeat(
                    fullName: nameController.text.trim(),
                    birthDate: birthDate!,
                    documentNumber: docController.text.trim(),
                ));
              },
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeatColor(Seat seat) {
    if (_selectedSeats.contains(seat)) {
      return Colors.blue;
    }
    if (seat.isBooked) {
      return Colors.red;
    }
    if (seat.isHeld) {
      return Colors.orange;
    }
    // Свободные места: EXTRA_LEGROOM выделяем отдельным цветом
    if (seat.category == 'EXTRA_LEGROOM') {
      return Colors.purple;
    }
    return Colors.green;
  }

  void _proceedToBooking() {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы одно место')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          flight: widget.flight,
          selectedSeats: _selectedSeats,
          passengerData: _passengerData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали рейса'),
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
                        onPressed: _loadSeatMap,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Информация о рейсе
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Рейс ${widget.flight.flightNumber}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      widget.flight.departureAirport.code,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('HH:mm').format(
                                        widget.flight.departureTime,
                                      ),
                                    ),
                                    Text(
                                      widget.flight.departureAirport.city,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      widget.flight.arrivalAirport.code,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('HH:mm').format(
                                        widget.flight.arrivalTime,
                                      ),
                                    ),
                                    Text(
                                      widget.flight.arrivalAirport.city,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Цена: ${widget.flight.basePrice.toStringAsFixed(0)} ₽',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Легенда мест
                  const Text(
                    'Выберите места:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildLegendItem(Colors.green, 'Свободно'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.purple, 'Extra legroom'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.orange, 'Удержано'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.red, 'Занято'),
                      const SizedBox(width: 16),
                      _buildLegendItem(Colors.blue, 'Выбрано'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Карта мест
                  if (_seatMap != null)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _seatMap!.seats.length,
                      itemBuilder: (context, index) {
                        final seat = _seatMap!.seats[index];
                        return GestureDetector(
                          onTap: () => _selectSeat(seat),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _getSeatColor(seat),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedSeats.contains(seat)
                                    ? Colors.blue
                                    : Colors.grey,
                                width: 2,
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
                      },
                    ),
                  const SizedBox(height: 24),
                  // Кнопка бронирования
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _proceedToBooking,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Забронировать (${_selectedSeats.length} мест)',
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _selectedSeats.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue,
              child: Text(
                'Выбрано мест: ${_selectedSeats.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

