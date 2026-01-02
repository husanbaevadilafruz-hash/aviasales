// staff_bookings_screen.dart - Экран просмотра бронирований (для STAFF)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class StaffBookingsScreen extends StatefulWidget {
  const StaffBookingsScreen({super.key});

  @override
  State<StaffBookingsScreen> createState() => _StaffBookingsScreenState();
}

class _StaffBookingsScreenState extends State<StaffBookingsScreen> {
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
      final bookings = await ApiService.getAllBookings();
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить бронирования';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Все бронирования'),
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
                  ? const Center(
                      child: Text('Нет бронирований'),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadBookings,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _bookings.length,
                        itemBuilder: (context, index) {
                          final booking = _bookings[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ExpansionTile(
                              leading: const Icon(Icons.confirmation_number, color: Colors.blue),
                              title: Text(
                                'Рейс ${booking.flight.flightNumber}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${booking.flight.departureAirport.city} → ${booking.flight.arrivalAirport.city}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Статус: ${booking.status}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: booking.status == 'CONFIRMED'
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Дата создания: ${DateFormat('dd.MM.yyyy HH:mm').format(booking.createdAt)}',
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'Билеты:',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      ...booking.tickets.map((ticket) {
                                        return Card(
                                          color: Colors.grey.shade100,
                                          child: ListTile(
                                            leading: const Icon(Icons.event_seat),
                                            title: Text('Место ${ticket.seat.seatNumber}'),
                                            subtitle: Text(
                                              ticket.fullName ?? 'Данные не заполнены',
                                            ),
                                            trailing: Text(
                                              ticket.ticketNumber ?? 'Без номера',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}








