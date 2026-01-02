// staff_bookings_screen.dart - Экран управления бронированиями (для STAFF)

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
  List<Booking> _filteredBookings = [];
  List<Flight> _flights = [];
  Flight? _selectedFlight;
  bool _isLoading = true;
  String? _errorMessage;
  
  final TextEditingController _pnrController = TextEditingController();
  Booking? _searchedBooking;
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pnrController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bookings = await ApiService.getAllBookings();
      final flights = await ApiService.searchFlights(showAll: true);
      
      setState(() {
        _bookings = bookings;
        _filteredBookings = bookings;
        _flights = flights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить данные: $e';
        _isLoading = false;
      });
    }
  }

  void _filterByFlight(Flight? flight) {
    setState(() {
      _selectedFlight = flight;
      if (flight == null) {
        _filteredBookings = _bookings;
      } else {
        _filteredBookings = _bookings.where((b) => b.flight.id == flight.id).toList();
      }
    });
  }

  Future<void> _searchByPnr() async {
    final pnr = _pnrController.text.trim();
    if (pnr.isEmpty) {
      setState(() {
        _searchError = 'Введите PNR';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchedBooking = null;
    });

    try {
      final booking = await ApiService.searchBookingByPnr(pnr);
      setState(() {
        _searchedBooking = booking;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = e.toString().replaceAll('Exception: ', '');
        _isSearching = false;
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _pnrController.clear();
      _searchedBooking = null;
      _searchError = null;
    });
  }

  Future<void> _cancelBooking(Booking booking) async {
    // Проверка времени до вылета
    final now = DateTime.now().toUtc();
    if (now.isAfter(booking.flight.departureTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя отменить бронирование после вылета рейса'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Диалог подтверждения
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отмена бронирования'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Вы уверены, что хотите отменить бронирование ${booking.pnr}?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('Рейс: ${booking.flight.flightNumber}'),
              const SizedBox(height: 8),
              Text(
                'Пассажир(ы): ${booking.tickets.map((t) => t.fullName ?? 'Н/Д').join(', ')}',
              ),
              const SizedBox(height: 8),
              Text(
                'Места: ${booking.tickets.map((t) => t.seat.seatNumber).join(', ')}',
              ),
              const SizedBox(height: 16),
              const Text(
                'Это действие нельзя отменить. Места будут освобождены.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Подтвердить отмену'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.staffCancelBooking(booking.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бронирование успешно отменено'),
          backgroundColor: Colors.green,
        ),
      );

      // Обновляем данные
      _loadData();
      _clearSearch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReassignSeatDialog(Booking booking, Ticket ticket) async {
    // Проверка времени до вылета
    final now = DateTime.now().toUtc();
    if (now.isAfter(booking.flight.departureTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя изменить место после вылета рейса'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Загружаем карту мест
    List<Seat> seats = [];
    try {
      final seatMap = await ApiService.getSeatMap(booking.flight.id);
      seats = seatMap.seats;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки мест: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Фильтруем только доступные места (AVAILABLE или HELD) + текущее место
    final availableSeats = seats.where((s) => 
      s.status == 'AVAILABLE' || 
      s.status == 'HELD' || 
      s.id == ticket.seat.id
    ).toList();

    if (availableSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных мест для переназначения'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Seat? selectedSeat;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Переназначить место для ${ticket.fullName ?? "пассажира"}'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Текущее место: ${ticket.seat.seatNumber}'),
                const SizedBox(height: 16),
                const Text('Выберите новое место:'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableSeats.length,
                    itemBuilder: (context, index) {
                      final seat = availableSeats[index];
                      final isCurrent = seat.id == ticket.seat.id;
                      final isSelected = selectedSeat?.id == seat.id;
                      
                      return ListTile(
                        leading: Icon(
                          Icons.event_seat,
                          color: isCurrent 
                            ? Colors.blue 
                            : seat.status == 'AVAILABLE' 
                              ? Colors.green 
                              : Colors.orange,
                        ),
                        title: Text(
                          seat.seatNumber,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(isCurrent ? 'Текущее' : seat.status),
                        selected: isSelected,
                        onTap: isCurrent ? null : () {
                          setState(() {
                            selectedSeat = seat;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: selectedSeat == null
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await _reassignSeat(booking, ticket, selectedSeat!);
                    },
              child: const Text('Переназначить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reassignSeat(Booking booking, Ticket ticket, Seat newSeat) async {
    try {
      final result = await ApiService.staffReassignSeat(
        bookingId: booking.id,
        ticketId: ticket.id,
        newSeatId: newSeat.id,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Место успешно переназначено'),
          backgroundColor: Colors.green,
        ),
      );

      // Обновляем данные
      _loadData();
      _clearSearch();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CONFIRMED':
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление бронированиями'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildContent(),
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
            onPressed: _loadData,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Панель поиска по PNR
        _buildPnrSearchPanel(),
        
        // Результат поиска по PNR
        if (_searchedBooking != null) _buildSearchResult(),
        
        const Divider(),
        
        // Фильтр по рейсу
        _buildFlightFilter(),
        
        // Список бронирований
        Expanded(
          child: _filteredBookings.isEmpty
              ? const Center(child: Text('Нет бронирований'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildBookingCard(_filteredBookings[index]);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPnrSearchPanel() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Поиск по PNR',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pnrController,
                  decoration: InputDecoration(
                    hintText: 'Введите код PNR',
                    border: const OutlineInputBorder(),
                    suffixIcon: _pnrController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) => setState(() {}),
                  onSubmitted: (_) => _searchByPnr(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isSearching ? null : _searchByPnr,
                child: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Найти'),
              ),
            ],
          ),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _searchError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResult() {
    final booking = _searchedBooking!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Результат поиска: ${booking.pnr}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSearch,
              ),
            ],
          ),
          _buildBookingCard(booking, isSearchResult: true),
        ],
      ),
    );
  }

  Widget _buildFlightFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Фильтр по рейсу: '),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<Flight?>(
              value: _selectedFlight,
              isExpanded: true,
              hint: const Text('Все рейсы'),
              items: [
                const DropdownMenuItem<Flight?>(
                  value: null,
                  child: Text('Все рейсы'),
                ),
                ..._flights.map((flight) => DropdownMenuItem<Flight?>(
                  value: flight,
                  child: Text(
                    '${flight.flightNumber} - ${flight.departureAirport.code} → ${flight.arrivalAirport.code} (${DateFormat('dd.MM.yy').format(flight.departureTime)})',
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ],
              onChanged: _filterByFlight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking, {bool isSearchResult = false}) {
    final canCancel = booking.status != 'CANCELLED' && 
        DateTime.now().toUtc().isBefore(booking.flight.departureTime);
    
    return Card(
      margin: EdgeInsets.only(bottom: isSearchResult ? 0 : 16),
      child: ExpansionTile(
        leading: Icon(
          Icons.confirmation_number,
          color: _getStatusColor(booking.status),
        ),
        title: Row(
          children: [
            Text(
              'PNR: ${booking.pnr}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(booking.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                booking.status,
                style: TextStyle(
                  color: _getStatusColor(booking.status),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Рейс ${booking.flight.flightNumber}: '
          '${booking.flight.departureAirport.city} → ${booking.flight.arrivalAirport.city}',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Информация о рейсе
                Row(
                  children: [
                    const Icon(Icons.flight_takeoff, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${DateFormat('dd.MM.yyyy HH:mm').format(booking.flight.departureTime)} - '
                        '${DateFormat('HH:mm').format(booking.flight.arrivalTime)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Дата создания: ${DateFormat('dd.MM.yyyy HH:mm').format(booking.createdAt)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                
                const SizedBox(height: 16),
                const Text(
                  'Билеты:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                
                // Список билетов с возможностью переназначения мест
                ...booking.tickets.map((ticket) {
                  return Card(
                    color: Colors.grey.shade100,
                    child: ListTile(
                      leading: const Icon(Icons.event_seat),
                      title: Text(ticket.fullName ?? 'Данные не заполнены'),
                      subtitle: Text('Место ${ticket.seat.seatNumber}'),
                      trailing: booking.status != 'CANCELLED'
                          ? IconButton(
                              icon: const Icon(Icons.swap_horiz, color: Colors.blue),
                              tooltip: 'Переназначить место',
                              onPressed: () => _showReassignSeatDialog(booking, ticket),
                            )
                          : null,
                    ),
                  );
                }),
                
                // Кнопки действий
                if (canCancel) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Отменить бронирование'),
                        onPressed: () => _cancelBooking(booking),
                      ),
                    ],
                  ),
                ],
                
                if (booking.status == 'CANCELLED')
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Это бронирование отменено',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
