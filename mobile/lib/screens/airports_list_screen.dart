// airports_list_screen.dart - Экран списка аэропортов (для STAFF)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class AirportsListScreen extends StatefulWidget {
  const AirportsListScreen({super.key});

  @override
  State<AirportsListScreen> createState() => _AirportsListScreenState();
}

class _AirportsListScreenState extends State<AirportsListScreen> {
  List<Airport> _airports = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAirports();
  }

  Future<void> _loadAirports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final airports = await ApiService.getAirports();
      setState(() {
        _airports = airports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить аэропорты: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showAirportFlights(Airport airport) async {
    // Показываем индикатор загрузки
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Загружаем рейсы, вылетающие из этого аэропорта
      final departingFlights = await ApiService.searchFlights(
        fromCode: airport.code,
        showAll: true,
      );

      // Загружаем рейсы, прилетающие в этот аэропорт
      final arrivingFlights = await ApiService.searchFlights(
        toCode: airport.code,
        showAll: true,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Закрываем индикатор загрузки

      // Показываем диалог с рейсами
      showDialog(
        context: context,
        builder: (context) => _AirportFlightsDialog(
          airport: airport,
          departingFlights: departingFlights,
          arrivingFlights: arrivingFlights,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Закрываем индикатор загрузки
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка загрузки рейсов: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Список аэропортов'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAirports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildAirportsList(),
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
            onPressed: _loadAirports,
            child: const Text('Попробовать снова'),
          ),
        ],
      ),
    );
  }

  Widget _buildAirportsList() {
    if (_airports.isEmpty) {
      return const Center(
        child: Text('Нет аэропортов'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAirports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _airports.length,
        itemBuilder: (context, index) {
          final airport = _airports[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: const Icon(Icons.airport_shuttle, size: 40),
              title: Text(
                airport.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Код: ${airport.code}'),
                  Text('${airport.city}, ${airport.country}'),
                ],
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showAirportFlights(airport),
            ),
          );
        },
      ),
    );
  }
}

class _AirportFlightsDialog extends StatelessWidget {
  final Airport airport;
  final List<Flight> departingFlights;
  final List<Flight> arrivingFlights;

  const _AirportFlightsDialog({
    required this.airport,
    required this.departingFlights,
    required this.arrivingFlights,
  });

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return Colors.blue;
      case 'DELAYED':
        return Colors.orange;
      case 'BOARDING':
        return Colors.purple;
      case 'DEPARTED':
        return Colors.green;
      case 'ARRIVED':
        return Colors.teal;
      case 'CANCELLED':
        return Colors.red;
      case 'COMPLETED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.airport_shuttle, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          airport.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '${airport.code} - ${airport.city}, ${airport.country}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Табы для вылетающих и прилетающих рейсов
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(
                          text: 'Вылетающие (${departingFlights.length})',
                        ),
                        Tab(
                          text: 'Прилетающие (${arrivingFlights.length})',
                        ),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildFlightsList(departingFlights, isDeparting: true),
                          _buildFlightsList(arrivingFlights, isDeparting: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightsList(List<Flight> flights, {required bool isDeparting}) {
    if (flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Нет ${isDeparting ? 'вылетающих' : 'прилетающих'} рейсов',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: flights.length,
      itemBuilder: (context, index) {
        final flight = flights[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(
              isDeparting ? Icons.flight_takeoff : Icons.flight_land,
              color: _getStatusColor(flight.status),
            ),
            title: Text(
              'Рейс ${flight.flightNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDeparting
                      ? '→ ${flight.arrivalAirport.city} (${flight.arrivalAirport.code})'
                      : '← ${flight.departureAirport.city} (${flight.departureAirport.code})',
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd.MM.yyyy HH:mm').format(flight.departureTime)} - ${DateFormat('HH:mm').format(flight.arrivalTime)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (flight.gate.isNotEmpty)
                  Text(
                    'Gate: ${flight.gate}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(flight.status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                flight.status,
                style: TextStyle(
                  color: _getStatusColor(flight.status),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

