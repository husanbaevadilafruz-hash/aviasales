// create_airport_screen.dart - Экран создания аэропорта (для STAFF)

import 'package:flutter/material.dart';
import '../api_service.dart';

class CreateAirportScreen extends StatefulWidget {
  const CreateAirportScreen({super.key});

  @override
  State<CreateAirportScreen> createState() => _CreateAirportScreenState();
}

class _CreateAirportScreenState extends State<CreateAirportScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _createAirport() async {
    if (_codeController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _countryController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Заполните все поля';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.createAirport(
        code: _codeController.text.trim().toUpperCase(),
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        country: _countryController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Аэропорт успешно создан!'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать аэропорт'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Код аэропорта (IATA)',
                hintText: 'Например: SVO, LED, DME',
                prefixIcon: Icon(Icons.flight_takeoff),
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название аэропорта',
                hintText: 'Например: Шереметьево',
                prefixIcon: Icon(Icons.airport_shuttle),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'Город',
                hintText: 'Например: Москва',
                prefixIcon: Icon(Icons.location_city),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Страна',
                hintText: 'Например: Россия',
                prefixIcon: Icon(Icons.public),
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createAirport,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Создать аэропорт'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

