// create_flight_screen.dart - Экран создания рейса (для STAFF)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../models.dart';

class CreateFlightScreen extends StatefulWidget {
  const CreateFlightScreen({super.key});

  @override
  State<CreateFlightScreen> createState() => _CreateFlightScreenState();
}

class _CreateFlightScreenState extends State<CreateFlightScreen> {
  final _flightNumberController = TextEditingController();
  final _priceController = TextEditingController();
  final _gateController = TextEditingController();
  
  List<Airport> _airports = [];
  List<Airplane> _airplanes = [];
  
  Airport? _selectedDepartureAirport;
  Airport? _selectedArrivalAirport;
  Airplane? _selectedAirplane;
  DateTime? _departureDateTime;
  DateTime? _arrivalDateTime;
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _priceController.dispose();
    _gateController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    try {
      final airports = await ApiService.getAirports();
      final airplanes = await ApiService.getAirplanes();
      setState(() {
        _airports = airports;
        _airplanes = airplanes;
        if (_airplanes.isNotEmpty) {
          _selectedAirplane = _airplanes.first;
        }
        _isLoadingData = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Не удалось загрузить данные';
        _isLoadingData = false;
      });
    }
  }

  Future<void> _selectDepartureDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _departureDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectArrivalDateTime() async {
    if (_departureDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите время вылета')),
      );
      return;
    }

    final date = await showDatePicker(
      context: context,
      initialDate: _departureDateTime!,
      firstDate: _departureDateTime!,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_departureDateTime!.add(const Duration(hours: 1))),
      );
      if (time != null) {
        setState(() {
          _arrivalDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createFlight() async {
    if (_flightNumberController.text.isEmpty ||
        _selectedDepartureAirport == null ||
        _selectedArrivalAirport == null ||
        _departureDateTime == null ||
        _arrivalDateTime == null ||
        _selectedAirplane == null ||
        _priceController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Заполните все поля, включая выбор самолёта';
      });
      return;
    }
    
    if (_airplanes.isEmpty) {
      setState(() {
        _errorMessage = 'Сначала создайте хотя бы один самолёт';
      });
      return;
    }

    if (_arrivalDateTime!.isBefore(_departureDateTime!)) {
      setState(() {
        _errorMessage = 'Время прилёта должно быть после времени вылета';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.createFlight(
        flightNumber: _flightNumberController.text.trim(),
        gate: _gateController.text.trim(),
        departureAirportId: _selectedDepartureAirport!.id,
        arrivalAirportId: _selectedArrivalAirport!.id,
        departureTime: _departureDateTime!,
        arrivalTime: _arrivalDateTime!,
        airplaneId: _selectedAirplane!.id,
        basePrice: double.parse(_priceController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Рейс успешно создан!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать рейс'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoadingData = true;
              });
              loadData();
            },
            tooltip: 'Обновить данные',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _flightNumberController,
              decoration: const InputDecoration(
                labelText: 'Номер рейса',
                hintText: 'Например: SU100',
                prefixIcon: Icon(Icons.flight),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gateController,
              decoration: const InputDecoration(
                labelText: 'Gate (выход на посадку)',
                hintText: 'Например: A12 (можно оставить пустым)',
                prefixIcon: Icon(Icons.door_front_door),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Airport>(
              value: _selectedDepartureAirport,
              decoration: const InputDecoration(
                labelText: 'Аэропорт отправления',
                prefixIcon: Icon(Icons.flight_takeoff),
                border: OutlineInputBorder(),
              ),
              items: _airports.map((airport) {
                return DropdownMenuItem(
                  value: airport,
                  child: Text('${airport.code} - ${airport.city}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDepartureAirport = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Airport>(
              value: _selectedArrivalAirport,
              decoration: const InputDecoration(
                labelText: 'Аэропорт прибытия',
                prefixIcon: Icon(Icons.flight_land),
                border: OutlineInputBorder(),
              ),
              items: _airports.map((airport) {
                return DropdownMenuItem(
                  value: airport,
                  child: Text('${airport.code} - ${airport.city}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedArrivalAirport = value;
                });
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDepartureDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата и время вылета',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _departureDateTime != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format(_departureDateTime!)
                      : 'Выберите дату и время',
                ),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectArrivalDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата и время прилёта',
                  prefixIcon: Icon(Icons.calendar_today),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _arrivalDateTime != null
                      ? DateFormat('yyyy-MM-dd HH:mm').format(_arrivalDateTime!)
                      : 'Выберите дату и время',
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Airplane>(
              value: _selectedAirplane,
              decoration: const InputDecoration(
                labelText: 'Самолёт',
                prefixIcon: Icon(Icons.airplanemode_active),
                border: OutlineInputBorder(),
              ),
              items: _airplanes.isEmpty
                  ? [
                      const DropdownMenuItem(
                        value: null,
                        enabled: false,
                        child: Text('Нет доступных самолётов'),
                      )
                    ]
                  : _airplanes.map((airplane) {
                      return DropdownMenuItem(
                        value: airplane,
                        child: Text('${airplane.model} (${airplane.totalSeats} мест)'),
                      );
                    }).toList(),
              onChanged: _airplanes.isEmpty
                  ? null
                  : (value) {
                      setState(() {
                        _selectedAirplane = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Базовая цена (₽)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
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
                onPressed: _isLoading ? null : _createFlight,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Создать рейс'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

