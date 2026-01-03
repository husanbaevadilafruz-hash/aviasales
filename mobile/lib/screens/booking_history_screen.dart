// booking_history_screen.dart - Экран истории покупок

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import 'boarding_pass_screen.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookings = await ApiService.getBookingHistory();
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить историю: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
      case 'PAID':
        return Colors.green;
      case 'CREATED':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      case 'PENDING_PAYMENT':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
        return 'Подтверждено';
      case 'PAID':
        return 'Оплачено';
      case 'CREATED':
        return 'Создано';
      case 'CANCELLED':
        return 'Отменено';
      case 'PENDING_PAYMENT':
        return 'Ожидает оплаты';
      default:
        return status;
    }
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
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История покупок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildHistoryList(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
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
            onPressed: _loadHistory,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'История покупок пуста',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final statusColor = _getStatusColor(booking.status);
    final isCancelled = booking.status == 'CANCELLED';
    final hasPayment = booking.payments.isNotEmpty;
    final totalAmount = booking.payments
        .where((p) => p.status == 'COMPLETED')
        .fold(0.0, (sum, p) => sum + p.amount);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isCancelled ? Colors.grey.shade100 : null,
      child: ExpansionTile(
        leading: Icon(
          isCancelled ? Icons.cancel : Icons.confirmation_number,
          color: statusColor,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'PNR: ${booking.pnr}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _getStatusText(booking.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${booking.flight.departureAirport.city} → ${booking.flight.arrivalAirport.city}',
            ),
            Text(
              'Рейс ${booking.flight.flightNumber}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            Text(
              'Дата покупки: ${DateFormat('dd.MM.yyyy HH:mm').format(booking.createdAt)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (hasPayment && totalAmount > 0)
              Text(
                'Сумма: ${totalAmount.toStringAsFixed(2)} ₽',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Информация о рейсе
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.flight_takeoff, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${DateFormat('dd.MM.yyyy HH:mm').format(booking.flight.departureTime)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Text(' → '),
                          Text(
                            '${DateFormat('HH:mm').format(booking.flight.arrivalTime)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (booking.flight.gate.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.door_front_door, size: 16),
                            const SizedBox(width: 8),
                            Text('Gate: ${booking.flight.gate}'),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Билеты
                const Text(
                  'Билеты:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...booking.tickets.map((ticket) {
                  return Card(
                    color: Colors.grey.shade50,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.event_seat),
                      title: Text(ticket.fullName ?? 'Данные не заполнены'),
                      subtitle: Text('Место ${ticket.seat.seatNumber}'),
                      trailing: ticket.checkIn != null
                          ? IconButton(
                              icon: const Icon(Icons.airplane_ticket, color: Colors.blue),
                              tooltip: 'Показать посадочный талон',
                              onPressed: () => _openBoardingPass(ticket.id),
                            )
                          : null,
                    ),
                  );
                }),
                
                // Информация о платежах
                if (booking.payments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Платежи:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...booking.payments.map((payment) {
                    return Card(
                      color: payment.status == 'COMPLETED'
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          payment.status == 'COMPLETED'
                              ? Icons.check_circle
                              : Icons.pending,
                          color: payment.status == 'COMPLETED'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Text(
                          '${payment.amount.toStringAsFixed(2)} ₽',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Метод: ${payment.method}'),
                            Text(
                              'Статус: ${payment.status}',
                              style: TextStyle(
                                color: payment.status == 'COMPLETED'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            Text(
                              'Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(payment.createdAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

