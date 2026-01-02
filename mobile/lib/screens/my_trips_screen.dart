// my_trips_screen.dart - Экран "Мои поездки"

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import 'boarding_pass_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({super.key});

  @override
  State<MyTripsScreen> createState() => MyTripsScreenState();
}

// Делаем State публичным для доступа через GlobalKey
class MyTripsScreenState extends State<MyTripsScreen> {
  // Публичный метод для обновления списка бронирований
  void refreshBookings() {
    _loadBookings();
  }

  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bookings = await ApiService.getMyBookings();
      setState(() {
        _bookings = bookings;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      setState(() {
        _errorMessage = 'Не удалось загрузить бронирования: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _payBooking(int bookingId) async {
    try {
      setState(() => _isLoading = true);
      await ApiService.payBooking(bookingId: bookingId, method: 'CARD');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Оплата успешна!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  bool _canCheckIn(Booking booking) {
    if (!(booking.status == 'CONFIRMED' || booking.status == 'PAID')) return false;
    final diff = booking.flight.departureTime.difference(DateTime.now());
    return diff <= const Duration(hours: 24) && diff >= const Duration(hours: 1);
  }

  Future<void> _openBoardingPass(int ticketId) async {
    try {
      final pass = await ApiService.getBoardingPass(ticketId);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BoardingPassScreen(pass: pass),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _checkInTicket(int ticketId) async {
    try {
      await ApiService.checkInTicket(ticketId);
      // После check-in открываем талон
      await _openBoardingPass(ticketId);
      // Обновляем список, чтобы кнопка исчезла (check_in появится в ответе)
      _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _cancelTicket(int ticketId, Booking booking) async {
    // Проверяем, что до рейса больше часа
    final timeUntilDeparture = booking.flight.departureTime.difference(DateTime.now());
    if (timeUntilDeparture.inHours < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя отменить билет за час до вылета'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена билета'),
        content: Text(booking.tickets.length == 1 
            ? 'Это последний билет. Бронирование будет полностью отменено. Продолжить?'
            : 'Вы уверены, что хотите отменить этот билет?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final result = await ApiService.cancelTicket(ticketId);
        if (mounted) {
          final message = result['booking_cancelled'] == true 
              ? 'Билет отменён. Бронирование закрыто.' 
              : 'Билет успешно отменён';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
            ),
          );
          _loadBookings();
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
  }

  Future<void> _cancelBooking(int bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена бронирования'),
        content: const Text('Вы уверены, что хотите отменить это бронирование?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Да'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.cancelBooking(bookingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Бронирование отменено'),
              backgroundColor: Colors.green,
            ),
          );
          _loadBookings();
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои поездки'),
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
                        onPressed: _loadBookings,
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                )
              : _bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flight, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                                  const Text(
                                    'У вас пока нет рейсов',
                                    style: TextStyle(fontSize: 18, color: Colors.grey),
                                  ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          return _buildBookingCard(booking);
                        },
                      ),
                    ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок рейса
            Row(
              children: [
                const Icon(Icons.flight, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Рейс ${booking.flight.flightNumber}',
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
              '${booking.flight.departureAirport.city} → ${booking.flight.arrivalAirport.city}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Divider(height: 24),
            
            // Информация о рейсе
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.flight.departureAirport.code ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM').format(booking.flight.departureTime),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        DateFormat('HH:mm').format(booking.flight.departureTime),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        booking.flight.departureAirport.city ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        booking.flight.arrivalAirport.code ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM').format(booking.flight.arrivalTime),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        DateFormat('HH:mm').format(booking.flight.arrivalTime),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        booking.flight.arrivalAirport.city ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Gate (выход на посадку) - отображаем в билете, если задан
            if (booking.flight.gate.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.door_front_door, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Text(
                    'Gate: ${booking.flight.gate}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            
            // Статус
            _buildStatusWidget(booking),
            const SizedBox(height: 16),
            
            // Билеты
            const Text(
              'Билеты:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...booking.tickets.map((ticket) {
              // Проверяем, можно ли отменить билет (не за час до вылета)
              final canCancel = (booking.status == 'CONFIRMED' || booking.status == 'PAID') && 
                  booking.flight.departureTime.difference(DateTime.now()).inHours >= 1;
              final canCheckIn = _canCheckIn(booking);
              
              return Card(
                color: Colors.grey.shade100,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.confirmation_number),
                        title: Text('Место ${ticket.seat.seatNumber}'),
                        subtitle: Text(ticket.fullName ?? 'Данные не заполнены'),
                        trailing: (canCheckIn && ticket.checkIn == null)
                            ? SizedBox(
                                height: 32,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                  ),
                                  onPressed: () => _checkInTicket(ticket.id),
                                  child: const Text('Чек-ин', style: TextStyle(fontSize: 12)),
                                ),
                              )
                            : (ticket.checkIn != null)
                                ? SizedBox(
                                    height: 32,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                      ),
                                      onPressed: () => _openBoardingPass(ticket.id),
                                      child: const Text('Талон', style: TextStyle(fontSize: 12)),
                                    ),
                                  )
                                : Text(ticket.ticketNumber ?? '', style: const TextStyle(fontSize: 10)),
                      ),
                      if (canCancel && booking.tickets.length > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _cancelTicket(ticket.id, booking),
                            icon: const Icon(Icons.cancel, color: Colors.red, size: 16),
                            label: const Text('Отменить билет', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            
            const SizedBox(height: 16),
            
            // Кнопки действий
            if (booking.status == 'PENDING_PAYMENT')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: booking.isExpired ? null : () => _payBooking(booking.id),
                  icon: const Icon(Icons.payment),
                  label: Text(booking.isExpired ? 'Время истекло' : 'Оплатить сейчас'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: booking.isExpired ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            
            if (booking.status == 'PENDING_PAYMENT' || booking.status == 'PAID')
              const SizedBox(height: 8),
            
            if (booking.status == 'PENDING_PAYMENT' || booking.status == 'PAID')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelBooking(booking.id),
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  label: const Text('Отменить бронирование', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusWidget(Booking booking) {
    Color statusColor;
    String statusText;

    switch (booking.status) {
      case 'PAID':
      case 'CONFIRMED':
        statusColor = Colors.green;
        statusText = 'Оплачено';
        break;
      case 'CANCELLED':
        statusColor = Colors.red;
        statusText = 'Отменено';
        break;
      case 'PENDING_PAYMENT':
      case 'CREATED':
        if (booking.isExpired) {
          statusColor = Colors.red;
          statusText = 'Истекло';
        } else {
          statusColor = Colors.orange;
          statusText = 'Ожидает оплаты';
        }
        break;
      default:
        statusColor = Colors.grey;
        statusText = booking.status;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Статус: $statusText',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
        // Таймер и кнопка оплаты для PENDING_PAYMENT/CREATED бронирований
        if ((booking.status == 'PENDING_PAYMENT' || booking.status == 'CREATED') && !booking.isExpired)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 16, color: Colors.orange),
                const SizedBox(width: 4),
                BookingTimer(
                  createdAt: booking.createdAt,
                  onExpired: () => _loadBookings(),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _payBooking(booking.id),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Оплатить'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class BookingTimer extends StatefulWidget {
  final DateTime createdAt;
  final VoidCallback? onExpired;

  const BookingTimer({
    super.key,
    required this.createdAt,
    this.onExpired,
  });

  @override
  State<BookingTimer> createState() => _BookingTimerState();
}

class _BookingTimerState extends State<BookingTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  bool _hasExpired = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  void _calculateRemaining() {
    final now = DateTime.now().toUtc();
    final timeDiff = now.difference(widget.createdAt);
    // Оставшееся время = 10 минут - (текущее время - created_at)
    _remaining = const Duration(minutes: 10) - timeDiff;
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _calculateRemaining();
      });

      if (_remaining <= Duration.zero) {
        _timer?.cancel();
        _timer = null;
        // Вызываем колбэк при истечении времени
        if (!_hasExpired && widget.onExpired != null) {
          _hasExpired = true;
          // Небольшая задержка перед вызовом колбэка
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              widget.onExpired!();
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining <= Duration.zero) {
      return const Text(
        '00:00 - Истекло',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.red,
        ),
      );
    }
    
    final totalSeconds = _remaining.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    return Text(
      '$minutes:$seconds',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: _remaining.inMinutes < 2 ? Colors.red : Colors.orange,
      ),
    );
  }
}
