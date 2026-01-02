// create_airplane_screen.dart - Экран создания самолёта (для STAFF)

import 'package:flutter/material.dart';
import '../api_service.dart';

class CreateAirplaneScreen extends StatefulWidget {
  const CreateAirplaneScreen({super.key});

  @override
  State<CreateAirplaneScreen> createState() => _CreateAirplaneScreenState();
}

class _CreateAirplaneScreenState extends State<CreateAirplaneScreen> {
  final _modelController = TextEditingController();
  final _rowsController = TextEditingController();
  final _seatsPerRowController = TextEditingController();
  final _seatLettersController = TextEditingController(text: 'ABCDEFGH');
  final _extraLegroomRowsController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _modelController.dispose();
    _rowsController.dispose();
    _seatsPerRowController.dispose();
    _seatLettersController.dispose();
    _extraLegroomRowsController.dispose();
    super.dispose();
  }

  Future<void> _createAirplane() async {
    if (_modelController.text.isEmpty ||
        _rowsController.text.isEmpty ||
        _seatsPerRowController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Заполните все обязательные поля';
      });
      return;
    }

    final rows = int.tryParse(_rowsController.text);
    final seatsPerRow = int.tryParse(_seatsPerRowController.text);

    if (rows == null || rows <= 0) {
      setState(() {
        _errorMessage = 'Количество рядов должно быть положительным числом';
      });
      return;
    }

    if (seatsPerRow == null || seatsPerRow <= 0) {
      setState(() {
        _errorMessage = 'Количество мест в ряду должно быть положительным числом';
      });
      return;
    }

    final seatLetters = _seatLettersController.text.trim();
    if (seatLetters.isEmpty) {
      setState(() {
        _errorMessage = 'Укажите буквы для мест';
      });
      return;
    }

    if (seatsPerRow > seatLetters.length) {
      setState(() {
        _errorMessage =
            'Количество мест в ряду ($seatsPerRow) не может превышать количество букв (${seatLetters.length})';
      });
      return;
    }

    // Парсим ряды с extra legroom (опционально): "1, 12, 13"
    List<int> extraLegroomRows = [];
    final extraRowsRaw = _extraLegroomRowsController.text.trim();
    if (extraRowsRaw.isNotEmpty) {
      try {
        extraLegroomRows = extraRowsRaw
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .where((r) => r > 0)
            .toList();
      } catch (_) {
        setState(() {
          _errorMessage = 'Неверный формат рядов Extra legroom. Пример: 1,12,13';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.createAirplane(
        model: _modelController.text.trim(),
        rows: rows,
        seatsPerRow: seatsPerRow,
        seatLetters: seatLetters,
        extraLegroomRows: extraLegroomRows,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Самолёт успешно создан! Сгенерировано ${rows * seatsPerRow} мест.'),
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
        title: const Text('Создать самолёт'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Модель самолёта',
                hintText: 'Например: Boeing 737',
                prefixIcon: Icon(Icons.airplanemode_active),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rowsController,
              decoration: const InputDecoration(
                labelText: 'Количество рядов',
                hintText: 'Например: 30',
                prefixIcon: Icon(Icons.view_column),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _seatsPerRowController,
              decoration: const InputDecoration(
                labelText: 'Мест в ряду',
                hintText: 'Например: 6',
                prefixIcon: Icon(Icons.event_seat),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _seatLettersController,
              decoration: const InputDecoration(
                labelText: 'Буквы для мест (опционально)',
                hintText: 'Например: ABCDEF',
                prefixIcon: Icon(Icons.abc),
                border: OutlineInputBorder(),
                helperText: 'По умолчанию: ABCDEFGH',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _extraLegroomRowsController,
              decoration: const InputDecoration(
                labelText: 'Extra legroom rows (опционально)',
                hintText: 'Например: 1,12,13',
                prefixIcon: Icon(Icons.airline_seat_legroom_extra),
                border: OutlineInputBorder(),
                helperText: 'Ряды с увеличенным пространством для ног',
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            const Text(
              'Места будут автоматически сгенерированы.\nПример: 1A, 1B, 1C, ..., 30F',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
                onPressed: _isLoading ? null : _createAirplane,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Создать самолёт'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

