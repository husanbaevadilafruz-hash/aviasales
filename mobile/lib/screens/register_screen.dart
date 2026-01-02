// register_screen.dart - Экран регистрации

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Profile Fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passportController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _dateOfBirth;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passportController.dispose();
    _nationalityController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), // Default to 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _register() async {
    setState(() {
      _errorMessage = null;
    });

    // 1. Basic Validation
    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _passportController.text.isEmpty ||
        _nationalityController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _dateOfBirth == null) {
      setState(() {
        _errorMessage = 'Пожалуйста, заполните все обязательные поля';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Пароли не совпадают';
      });
      return;
    }

    if (_passwordController.text.length < 6) {
      setState(() {
        _errorMessage = 'Пароль должен быть не менее 6 символов';
      });
      return;
    }

    // 2. Age Validation (Client Side)
    // Approximate calculation
    final age = (DateTime.now().difference(_dateOfBirth!).inDays / 365).floor();
    if (age < 16) {
       setState(() {
        _errorMessage = 'Вам должно быть не менее 16 лет для регистрации';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 3. Register User
      await ApiService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // 4. Create Profile
      // ApiService.register already logs in and saves token
      await ApiService.createProfile(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _dateOfBirth!,
        passportNumber: _passportController.text.trim(),
        nationality: _nationalityController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (mounted) {
        // Navigate
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainScreen()),
        );
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
        title: const Text('Регистрация пассажира'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(Icons.flight_takeoff, size: 60, color: Colors.blue),
            const SizedBox(height: 20),
            
            // Login Info
            const Text("Данные для входа", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Пароль *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Подтвердите пароль *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
              obscureText: true,
            ),

            const Divider(height: 30),

            // Personal Info
            const Text("Личные данные", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'Имя *', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Фамилия *', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Дата рождения *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _dateOfBirth == null 
                      ? 'Выберите дату' 
                      : DateFormat('dd.MM.yyyy').format(_dateOfBirth!),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passportController,
              decoration: const InputDecoration(labelText: 'Номер паспорта *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_box)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nationalityController,
              decoration: const InputDecoration(labelText: 'Гражданство *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.flag)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Телефон *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Зарегистрироваться', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Уже есть аккаунт? Войти'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
