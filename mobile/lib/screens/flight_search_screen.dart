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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск рейсов'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.announcement),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.flight),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MyTripsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Форма поиска
            Card(
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
                      child: ElevatedButton(
                        onPressed: _isLoading || _isLoadingAirports
                            ? null
                            : _searchFlights,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Найти рейсы'),
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
              const Center(
                child: Text('Рейсы не найдены'),
              )
            else
              ..._flights.map((flight) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ListTile(
                    leading: const Icon(Icons.flight, size: 40),
                    title: Text(
                      '${flight.departureAirport.code} → ${flight.arrivalAirport.code}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Рейс: ${flight.flightNumber}'),
                        Text(
                          'Дата: ${DateFormat('dd MMM yyyy').format(flight.departureTime)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Вылет: ${DateFormat('HH:mm').format(flight.departureTime)} - Прилёт: ${DateFormat('HH:mm').format(flight.arrivalTime)}',
                        ),
                        Text(
                          '${flight.departureAirport.city} → ${flight.arrivalAirport.city}',
                        ),
                        Text(
                          '${flight.basePrice.toStringAsFixed(0)} ₽',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FlightDetailsScreen(flight: flight),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
}

