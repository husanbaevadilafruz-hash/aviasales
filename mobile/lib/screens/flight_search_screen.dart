// flight_search_screen.dart - Экран поиска рейсов

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';
import 'flight_details_screen.dart';
import 'my_trips_screen.dart';
import 'announcements_screen.dart';

class FlightSearchScreen extends StatefulWidget {
  const FlightSearchScreen({super.key});

  @override
  State<FlightSearchScreen> createState() => _FlightSearchScreenState();
}

class _FlightSearchScreenState extends State<FlightSearchScreen> {
  List<Airport> _airports = [];
  Airport? _selectedFromAirport;
  Airport? _selectedToAirport;
  DateTime? _selectedDate;
  List<Flight> _flights = [];
  bool _isLoading = false;
  bool _isLoadingAirports = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAirports();
  }

  Future<void> _loadAirports() async {
    try {
      final airports = await ApiService.getAirports();
      setState(() {
        _airports = airports;
        _isLoadingAirports = false;
      });
      // После загрузки аэропортов загружаем все рейсы сразу
      _searchFlights(initial: true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить аэропорты';
        _isLoadingAirports = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _searchFlights({bool initial = false}) async {
    // Если это не первоначальная загрузка, проверяем выбор аэропортов
    if (!initial && (_selectedFromAirport == null || _selectedToAirport == null)) {
      setState(() {
        _errorMessage = 'Выберите аэропорты отправления и прибытия';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final flights = await ApiService.searchFlights(
        fromCode: _selectedFromAirport?.code,
        toCode: _selectedToAirport?.code,
        date: _selectedDate,
      );

      setState(() {
        _flights = flights;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось найти рейсы';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF6B46C1);
    const Color lightPurple = Color(0xFFE9D5FF);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Search Flights',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryPurple,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.announcement, color: primaryPurple),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.flight, color: primaryPurple),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyTripsScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              lightPurple.withOpacity(0.2),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Форма поиска
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Аэропорт отправления (Searchable)
                      Autocomplete<Airport>(
                        displayStringForOption: (airport) => '${airport.code} - ${airport.city}',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Airport>.empty();
                          }
                          return _airports.where((Airport option) {
                            return option.city.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                   option.code.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (Airport selection) {
                          setState(() {
                            _selectedFromAirport = selection;
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            decoration: const InputDecoration(
                              labelText: 'Откуда (город или код)',
                              prefixIcon: Icon(Icons.flight_takeoff),
                              border: OutlineInputBorder(),
                              hintText: 'Начните вводить...',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Аэропорт прибытия (Searchable)
                      Autocomplete<Airport>(
                        displayStringForOption: (airport) => '${airport.code} - ${airport.city}',
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<Airport>.empty();
                          }
                          return _airports.where((Airport option) {
                            return option.city.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                   option.code.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (Airport selection) {
                          setState(() {
                            _selectedToAirport = selection;
                          });
                        },
                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            decoration: const InputDecoration(
                              labelText: 'Куда (город или код)',
                              prefixIcon: Icon(Icons.flight_land),
                              border: OutlineInputBorder(),
                              hintText: 'Начните вводить...',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Дата
                      InkWell(
                        onTap: _selectDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Дата',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            _selectedDate != null
                                ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                                : 'Выберите дату',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading || _isLoadingAirports
                              ? null
                              : _searchFlights,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Search Flights',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
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
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            // Список рейсов
            if (_flights.isEmpty && !_isLoading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No flights found',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ),
              )
            else
              ..._flights.map((flight) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FlightDetailsScreen(flight: flight),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.flight, color: primaryPurple, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${flight.departureAirport.code} → ${flight.arrivalAirport.code}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: primaryPurple,
                                      ),
                                    ),
                                    Text(
                                      '${flight.departureAirport.city} → ${flight.arrivalAirport.city}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${flight.basePrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: primaryPurple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${DateFormat('MMM dd, yyyy').format(flight.departureTime)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormat('HH:mm').format(flight.departureTime)} → ${DateFormat('HH:mm').format(flight.arrivalTime)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(
                                'Flight: ${flight.flightNumber}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
      ),
    );
  }
}

