// booking_screen.dart - Экран бронирования и оплаты

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import 'my_trips_screen.dart';
import 'main_screen.dart';

class BookingScreen extends StatefulWidget {
  final Flight flight;
  final List<Seat> selectedSeats;
  final Map<int, PassengerPerSeat> passengerData;

  const BookingScreen({
    super.key,
    required this.flight,
    required this.selectedSeats,
    required this.passengerData,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  bool _isLoading = false;
  bool _hasProfile = false;
  bool _checkingProfile = true;
  String? _errorMessage;
  String _selectedPaymentMethod = 'CARD';

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkProfile() async {
    try {
      final profile = await ApiService.getProfile();
      setState(() {
        _hasProfile = profile != null;
        _checkingProfile = false;
      });

      if (!_hasProfile) {
        _showProfileDialog();
      }
    } catch (e) {
      setState(() {
        _checkingProfile = false;
      });
    }
  }

  void _showProfileDialog() {
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final passportController = TextEditingController();
    final phoneController = TextEditingController();
    final nationalityController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Заполните профиль'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    labelText: 'Фамилия',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime(1990, 1, 1),
                      firstDate: DateTime(1900, 1, 1),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setDialogState(() {
                        selectedDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Дата рождения',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(
                      selectedDate != null
                          ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                          : 'Выберите дату',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passportController,
                  decoration: const InputDecoration(
                    labelText: 'Номер паспорта',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nationalityController,
                  decoration: const InputDecoration(
                    labelText: 'Гражданство',
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
              onPressed: () async {
                if (firstNameController.text.isEmpty ||
                    lastNameController.text.isEmpty ||
                    selectedDate == null ||
                    passportController.text.isEmpty ||
                    phoneController.text.isEmpty ||
                    nationalityController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Заполните все обязательные поля'),
                    ),
                  );
                  return;
                }

                try {
                  await ApiService.createProfile(
                    firstName: firstNameController.text,
                    lastName: lastNameController.text,
                    dateOfBirth: selectedDate!,
                    passportNumber: passportController.text,
                    phone: phoneController.text,
                    nationality: nationalityController.text,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {
                      _hasProfile = true;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceAll('Exception: ', ''),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBooking({bool onlyPayLater = false}) async {
    if (!_hasProfile) {
      _showProfileDialog();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Создаём бронирование (статус PENDING_PAYMENT, expires_at через 10 минут)
      final booking = await ApiService.createBooking(
        flightId: widget.flight.id,
        seatIds: widget.selectedSeats.map((s) => s.id).toList(),
      );

      // 2. Если выбрана оплата сразу - оплачиваем
      if (!onlyPayLater) {
        await ApiService.payBooking(
          bookingId: booking.id,
          method: _selectedPaymentMethod,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(onlyPayLater 
                ? 'Бронирование создано! У вас есть 10 минут на оплату. Перейдите в "Мои поездки" для оплаты.' 
                : 'Бронирование успешно создано и оплачено!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Возвращаемся на главный экран и переключаемся на вкладку "Мои поездки"
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        // Переключаемся на вкладку "Мои поездки" и обновляем список
        final mainScreenState = MainScreen.mainScreenKey.currentState;
        if (mainScreenState != null) {
          // Сначала обновляем данные, потом переключаем вкладку
          mainScreenState.refreshBookings();
          // Небольшая задержка перед переключением для загрузки данных
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            mainScreenState.setIndex(1);
          }
        }
      }
    } catch (e) {
      print('Error creating booking: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  double get _totalPrice {
    return widget.flight.basePrice * widget.selectedSeats.length;
  }

  Widget _buildPassengerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Данные пассажиров:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...widget.selectedSeats.map((seat) {
          final data = widget.passengerData[seat.id];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text('${seat.seatNumber}: ${data?.fullName ?? "Нет данных"}'),
              subtitle: Text('Документ: ${data?.documentNumber ?? "-"}'),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бронирование'),
      ),
      body: SingleChildScrollView(
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.flight.departureAirport.city} → ${widget.flight.arrivalAirport.city}',
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, HH:mm').format(
                        widget.flight.departureTime,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Выбранные места
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выбранные места:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: widget.selectedSeats
                          .map((seat) => Chip(
                                label: Text(seat.seatNumber),
                                backgroundColor: Colors.blue,
                                labelStyle: const TextStyle(color: Colors.white),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Список пассажиров (только чтение)
            _buildPassengerList(),
            const SizedBox(height: 16),
            // Способ оплаты
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Способ оплаты:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      title: const Text('Банковская карта'),
                      value: 'CARD',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Apple Pay'),
                      value: 'APPLE_PAY',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      title: const Text('Google Pay'),
                      value: 'GOOGLE_PAY',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Итого
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Итого:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_totalPrice.toStringAsFixed(0)} ₽',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _createBooking(onlyPayLater: false),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Оплатить и забронировать',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _createBooking(onlyPayLater: true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.blue),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Забронировать без оплаты',
                        style: TextStyle(fontSize: 16, color: Colors.blue),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

