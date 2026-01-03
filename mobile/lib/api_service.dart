// api_service.dart - Сервис для работы с API

// Этот файл содержит ВСЕ HTTP запросы к backend.
// Flutter приложение общается с FastAPI только через этот файл.

// Это как "телефон" для связи с сервером:
// - Все запросы идут отсюда
// - JWT токен добавляется автоматически
// - Ошибки обрабатываются здесь

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

import 'package:flutter/foundation.dart';

class ApiService {
  // Базовый URL API
  // Для эмулятора Android: http://10.0.2.2:8000
  // Для Flutter web / Desktop: http://127.0.0.1:8000
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }
    // Для мобильных устройств (эмуляторов)
    return 'http://10.0.2.2:8000';
  }

  // Получить сохранённый JWT токен
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Сохранить JWT токен
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // Удалить токен (при выходе)
  static Future<void> _removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  // Создать заголовки с токеном
  static Future<Map<String, String>> _getHeaders({bool needAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (needAuth) {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        debugPrint('JWT Token present: ${token.length > 20 ? token.substring(0, 20) + "..." : token}');
      } else {
        debugPrint('WARNING: JWT Token is NULL or EMPTY!');
        throw Exception('Authentication required. Please login again.');
      }
    }

    return headers;
  }

  // ============================================
  // АУТЕНТИФИКАЦИЯ
  // ============================================

  // Регистрация
  static Future<User> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: await _getHeaders(needAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
          'role': 'PASSENGER',
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final responseBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(responseBody);
        final token = data['access_token'];
        await _saveToken(token);
        return User(email: email, role: 'PASSENGER', token: token);
      } else {
        try {
          final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
          throw Exception(error['detail'] ?? 'Registration failed');
        } catch (e) {
          throw Exception('Registration failed: ${response.statusCode}');
        }
      }
    } on http.ClientException catch (e) {
      throw Exception('Не удалось подключиться к серверу. Убедитесь, что backend запущен на $baseUrl');
    } on FormatException catch (e) {
      throw Exception('Ошибка обработки ответа сервера');
    } catch (e) {
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed to fetch')) {
        throw Exception('Не удалось подключиться к серверу. Убедитесь, что backend запущен на $baseUrl');
      }
      rethrow;
    }
  }

  // Вход
  static Future<User> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: await _getHeaders(needAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
      final data = jsonDecode(responseBody);
        final token = data['access_token'];
        await _saveToken(token);
        
        // Получаем роль из JWT токена
        String role = 'PASSENGER'; // По умолчанию
        try {
          // JWT токен: header.payload.signature
          final parts = token.split('.');
          if (parts.length == 3) {
            // Декодируем payload (base64url)
            String payload = parts[1];
            // Добавляем padding для base64
            switch (payload.length % 4) {
              case 1: payload += '==='; break;
              case 2: payload += '=='; break;
              case 3: payload += '='; break;
            }
            // Заменяем base64url символы на base64
            payload = payload.replaceAll('-', '+').replaceAll('_', '/');
            // Декодируем base64
            final decodedBytes = base64Decode(payload);
            final decoded = utf8.decode(decodedBytes);
            final payloadData = jsonDecode(decoded);
            role = payloadData['role'] ?? 'PASSENGER';
          }
        } catch (e) {
          // Если не удалось декодировать, проверяем по email
          if (email.contains('staff') || email.contains('airline')) {
            role = 'STAFF';
          }
        }
        
        return User(email: email, role: role, token: token);
      } else {
        try {
          final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
          throw Exception(error['detail'] ?? 'Login failed');
        } catch (e) {
          throw Exception('Login failed: ${response.statusCode}');
        }
      }
    } on http.ClientException catch (e) {
      throw Exception('Не удалось подключиться к серверу. Убедитесь, что backend запущен на $baseUrl');
    } on FormatException catch (e) {
      throw Exception('Ошибка обработки ответа сервера');
    } catch (e) {
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Failed to fetch')) {
        throw Exception('Не удалось подключиться к серверу. Убедитесь, что backend запущен на $baseUrl');
      }
      rethrow;
    }
  }

  // Выход
  static Future<void> logout() async {
    await _removeToken();
  }

  // ============================================
  // ПРОФИЛЬ ПАССАЖИРА
  // ============================================

  // Создать/обновить профиль
  static Future<PassengerProfile> createProfile({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String passportNumber,
    required String phone,
    required String nationality,
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/passenger/profile'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth.toIso8601String(),
        'passport_number': passportNumber,
        'phone': phone,
        'nationality': nationality,
        'email': email,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      return PassengerProfile.fromJson(jsonDecode(responseBody));
    } else {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to create profile');
    }
  }

  // Получить профиль
  static Future<PassengerProfile?> getProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/passenger/profile'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      return PassengerProfile.fromJson(jsonDecode(responseBody));
    } else if (response.statusCode == 404) {
      return null; // Профиль не создан
    } else {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to get profile');
    }
  }

  // ============================================
  // АЭРОПОРТЫ
  // ============================================

  // Получить список аэропортов
  static Future<List<Airport>> getAirports() async {
    final response = await http.get(
      Uri.parse('$baseUrl/airports'),
      headers: await _getHeaders(needAuth: false),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((json) => Airport.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load airports');
    }
  }

  // Получить список самолётов (для STAFF)
  static Future<List<Airplane>> getAirplanes() async {
    final response = await http.get(
      Uri.parse('$baseUrl/airplanes'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((json) => Airplane.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load airplanes');
    }
  }

  // Получить все места самолета по его ID
  static Future<List<Seat>> getAirplaneSeats(int airplaneId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/airplanes/$airplaneId/seats'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((json) => Seat.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load airplane seats');
    }
  }

  // ============================================
  // РЕЙСЫ
  // ============================================

  // Поиск рейсов
  static Future<List<Flight>> searchFlights({
    String? fromCode,
    String? toCode,
    DateTime? date,
    bool showAll = false,  // Для сотрудника - показать все рейсы
  }) async {
    final queryParams = <String, String>{};
    if (fromCode != null && fromCode.isNotEmpty) {
      queryParams['from_code'] = fromCode;
    }
    if (toCode != null && toCode.isNotEmpty) {
      queryParams['to_code'] = toCode;
    }
    if (date != null) {
      queryParams['date'] = date.toIso8601String().split('T')[0]; // YYYY-MM-DD
    }
    if (showAll) {
      queryParams['show_all'] = 'true';
    }

    final uri = Uri.parse('$baseUrl/flights/search').replace(
      queryParameters: queryParams,
    );

    final response = await http.get(
      uri,
      headers: await _getHeaders(needAuth: false),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((json) => Flight.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search flights');
    }
  }

  // Получить детали рейса
  static Future<Flight> getFlight(int flightId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/flights/$flightId'),
      headers: await _getHeaders(needAuth: false),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      return Flight.fromJson(jsonDecode(responseBody));
    } else {
      throw Exception('Failed to load flight');
    }
  }

  // ============================================
  // МЕСТА
  // ============================================

  // Получить карту мест
  static Future<SeatMap> getSeatMap(int flightId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/flights/$flightId/seat-map'),
      headers: await _getHeaders(needAuth: false),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      return SeatMap.fromJson(jsonDecode(responseBody));
    } else {
      throw Exception('Failed to load seat map');
    }
  }

  // Удержать место
  static Future<void> holdSeat(int seatId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seats/$seatId/hold'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to hold seat');
    }
  }

  // ============================================
  // БРОНИРОВАНИЯ
  // ============================================

  // Создать бронирование
  static Future<Booking> createBooking({
    required int flightId,
    required List<int> seatIds,
  }) async {
    try {
      final url = '$baseUrl/bookings';
      final headers = await _getHeaders();
      final body = jsonEncode({
        'flight_id': flightId,
        'seat_ids': seatIds,
      });
      
      // Логирование для отладки - ПОЛНЫЙ URL
      debugPrint('=' * 50);
      debugPrint('POST /bookings - CREATE BOOKING REQUEST');
      debugPrint('FULL URL: $url');
      debugPrint('Headers: $headers');
      debugPrint('Body: $body');
      debugPrint('=' * 50);
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint('Response status: ${response.statusCode}');
      
      // Используем utf8.decode для правильной обработки UTF-8
      final responseBodyUtf8 = utf8.decode(response.bodyBytes);
      debugPrint('Response Body (UTF-8): $responseBodyUtf8');

      if (response.statusCode == 201) {
        // После создания бронирования получаем полную информацию
        final bookingId = jsonDecode(responseBodyUtf8)['id'];
        // Небольшая задержка, чтобы бэкенд успел сохранить данные
        await Future.delayed(const Duration(milliseconds: 300));
        // Получаем все бронирования и находим нужное
        final bookings = await getMyBookings();
        try {
          return bookings.firstWhere((b) => b.id == bookingId);
        } catch (e) {
          // Если не нашли сразу, пробуем еще раз через секунду
          await Future.delayed(const Duration(seconds: 1));
          final bookings2 = await getMyBookings();
          return bookings2.firstWhere((b) => b.id == bookingId);
        }
      } else {
        final responseBodyUtf8 = utf8.decode(response.bodyBytes);
        debugPrint('Error response body: $responseBodyUtf8');
        try {
          final error = jsonDecode(responseBodyUtf8);
          throw Exception(error['detail'] ?? 'Failed to create booking');
        } catch (e) {
          throw Exception('Failed to create booking: $responseBodyUtf8');
        }
      }
    } catch (e) {
      debugPrint('Error in createBooking: $e');
      rethrow;
    }
  }

  // Получить все мои бронирования
  static Future<List<Booking>> getMyBookings() async {
    final url = '$baseUrl/bookings/my';
    final headers = await _getHeaders();
    
    // Логирование для отладки - ПОЛНЫЙ URL
    debugPrint('=' * 50);
    debugPrint('GET /bookings/my - GET MY BOOKINGS REQUEST');
    debugPrint('FULL URL: $url');
    debugPrint('Headers: $headers');
    debugPrint('=' * 50);
    
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    debugPrint('Response status: ${response.statusCode}');
    
    // Используем utf8.decode для правильной обработки UTF-8
    final responseBodyUtf8 = utf8.decode(response.bodyBytes);
    debugPrint('Response Body (UTF-8): $responseBodyUtf8');

    if (response.statusCode == 200) {
      try {
        final responseBody = responseBodyUtf8;
        // Если ответ пустой, возвращаем пустой список
        if (responseBody.isEmpty || responseBody.trim() == '') {
          debugPrint('Empty response, returning empty list');
          return [];
        }
        
        final List<dynamic> data = jsonDecode(responseBody);
        if (data.isEmpty) {
          debugPrint('Empty array in response - returning empty list');
          return [];
        }
        
        final List<Booking> bookings = [];
        for (final json in data) {
          try {
            // Пропускаем бронирования без рейса
            if (json['flight'] == null) {
              debugPrint('Skipping booking without flight: ${json['id']}');
              continue;
            }
            bookings.add(Booking.fromJson(json));
          } catch (e) {
            debugPrint('Error parsing booking: $e');
            debugPrint('Booking JSON: $json');
            // Пропускаем проблемное бронирование вместо краша
            continue;
          }
        }
        return bookings;
      } catch (e) {
        debugPrint('Error in getMyBookings: $e');
        throw Exception('Failed to parse bookings: $e');
      }
    } else {
      debugPrint('ERROR: Status code ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Failed to load bookings: ${response.statusCode}');
    }
  }

  // Получить историю покупок (все бронирования, включая отмененные)
  static Future<List<Booking>> getBookingHistory() async {
    final response = await http.get(
      Uri.parse('$baseUrl/bookings/history'),
      headers: await _getHeaders(),
    );

    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      try {
        if (responseBody.isEmpty || responseBody.trim() == '') {
          return [];
        }
        
        final List<dynamic> data = jsonDecode(responseBody);
        if (data.isEmpty) {
          return [];
        }
        
        final List<Booking> bookings = [];
        for (final json in data) {
          try {
            // Пропускаем бронирования без рейса
            if (json['flight'] == null) {
              continue;
            }
            bookings.add(Booking.fromJson(json));
          } catch (e) {
            debugPrint('Error parsing booking in history: $e');
            // Пропускаем проблемное бронирование
            continue;
          }
        }
        return bookings;
      } catch (e) {
        debugPrint('Error parsing booking history: $e');
        throw Exception('Failed to parse booking history');
      }
    } else {
      throw Exception('Failed to load booking history');
    }
  }

  // ============================================
  // CHECK-IN
  // ============================================

  static Future<CheckIn> checkInTicket(int ticketId) async {
    final url = '$baseUrl/tickets/$ticketId/check-in';
    final headers = await _getHeaders();

    debugPrint('POST /tickets/$ticketId/check-in');
    debugPrint('FULL URL: $url');

    final response = await http.post(
      Uri.parse(url),
      headers: headers,
    );

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return CheckIn.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    try {
      final error = jsonDecode(body);
      throw Exception(error['detail'] ?? 'Failed to check-in');
    } catch (_) {
      throw Exception('Failed to check-in: $body');
    }
  }

  static Future<BoardingPass> getBoardingPass(int ticketId) async {
    final url = '$baseUrl/tickets/$ticketId/boarding-pass';
    final headers = await _getHeaders();

    debugPrint('GET /tickets/$ticketId/boarding-pass');
    debugPrint('FULL URL: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200) {
      return BoardingPass.fromJson(jsonDecode(body) as Map<String, dynamic>);
    }

    try {
      final error = jsonDecode(body);
      throw Exception(error['detail'] ?? 'Failed to load boarding pass');
    } catch (_) {
      throw Exception('Failed to load boarding pass: $body');
    }
  }

  // ============================================
  // ПЛАТЕЖИ
  // ============================================

  // Оплатить бронирование
  static Future<void> payBooking({
    required int bookingId,
    required String method, // 'CARD', 'APPLE_PAY', 'GOOGLE_PAY'
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'booking_id': bookingId,
        'method': method,
      }),
    );

    if (response.statusCode != 201) {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Payment failed');
    }
  }

  // Отменить отдельный билет
  static Future<Map<String, dynamic>> cancelTicket(int ticketId) async {
    final url = '$baseUrl/tickets/$ticketId';
    final headers = await _getHeaders();
    
    debugPrint('=== CANCEL TICKET REQUEST ===');
    debugPrint('URL: $url');
    debugPrint('=============================');
    
    final response = await http.delete(
      Uri.parse(url),
      headers: headers,
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final error = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(error['detail'] ?? 'Failed to cancel ticket');
    }
  }

  // ============================================
  // CHECK-IN
  // ============================================

  // Регистрация на рейс
  static Future<void> checkIn(int ticketId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/passengers/$ticketId/check-in'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Check-in failed');
    }
  }

  // ============================================
  // ОБЪЯВЛЕНИЯ
  // ============================================

  // Получить все объявления
  static Future<List<Announcement>> getAnnouncements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/announcements'),
        headers: await _getHeaders(needAuth: false),
      );

      debugPrint('Announcements response: ${response.statusCode}');
      debugPrint('Announcements body: ${utf8.decode(response.bodyBytes)}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<Announcement> announcements = [];
        for (final json in data) {
          try {
            announcements.add(Announcement.fromJson(json));
          } catch (e) {
            debugPrint('Error parsing announcement: $e');
            debugPrint('Announcement JSON: $json');
            // Пропускаем проблемное объявление
            continue;
          }
        }
        return announcements;
      } else {
        throw Exception('Failed to load announcements: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getAnnouncements: $e');
      rethrow;
    }
  }

  // ============================================
  // STAFF ФУНКЦИИ
  // ============================================

  // Создать самолёт
  // Создать самолёт (для STAFF) - автоматическая генерация мест
  static Future<Airplane> createAirplane({
    required String model,
    required int rows,
    required int seatsPerRow,
    String seatLetters = 'ABCDEFGH',
    List<int>? extraLegroomRows,
  }) async {
    // ЛОГИРОВАНИЕ
    final requestBody = {
      'model': model,
      'rows': rows,
      'seats_per_row': seatsPerRow,
      'seat_letters': seatLetters,
      'seats': [], // Пустой список, чтобы сработала логика на бэке
    };
    if (extraLegroomRows != null && extraLegroomRows.isNotEmpty) {
      requestBody['extra_legroom_rows'] = extraLegroomRows;
    }
    final jsonBody = jsonEncode(requestBody);
    print('=' * 50);
    print('FLUTTER LOG: POST $baseUrl/airplanes');
    print('Request body: $jsonBody');
    print('=' * 50);
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/airplanes'),
        headers: await _getHeaders(),
        body: jsonBody,
      );

      print('FLUTTER LOG: Response status: ${response.statusCode}');
      
      if (response.statusCode == 201) {
        print('SUCCESS: Airplane created');
        final responseBody = utf8.decode(response.bodyBytes);
      return Airplane.fromJson(jsonDecode(responseBody));
      } else {
        final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
        print('ERROR: ${error['detail']}');
        throw Exception(error['detail'] ?? 'Failed to create airplane');
      }
    } catch (e) {
      print('FLUTTER LOG: Error making request: $e');
      rethrow;
    }
  }

  // Удалить самолёт (для STAFF)
  static Future<void> deleteAirplane(int airplaneId) async {
    print('FLUTTER LOG: DELETE $baseUrl/airplanes/$airplaneId');
    final response = await http.delete(
      Uri.parse('$baseUrl/airplanes/$airplaneId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 204) {
       final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
       throw Exception(error['detail'] ?? 'Failed to delete airplane');
    }
  }

  // Создать рейс
  static Future<Flight> createFlight({
    required String flightNumber,
    required int departureAirportId,
    required int arrivalAirportId,
    required DateTime departureTime,
    required DateTime arrivalTime,
    required int airplaneId,
    required double basePrice,
    String gate = "",
  }) async {
    print('FLUTTER LOG: POST $baseUrl/flights');
    final response = await http.post(
      Uri.parse('$baseUrl/flights'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'flight_number': flightNumber,
        'departure_airport_id': departureAirportId,
        'arrival_airport_id': arrivalAirportId,
        'departure_time': departureTime.toIso8601String(),
        'arrival_time': arrivalTime.toIso8601String(),
        'airplane_id': airplaneId,
        'base_price': basePrice,
        'gate': gate,
      }),
    );

    if (response.statusCode == 201) {
      // После создания нужно получить полную информацию с аэропортами
      final flightId = jsonDecode(response.body)['id'];
      return await getFlight(flightId);
    } else {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to create flight');
    }
  }

  // Обновить статус рейса (для STAFF)
  // При статусе DELAYED можно также указать новое время вылета/прилёта
  static Future<Flight> updateFlightStatus({
    required int flightId,
    required String status, // 'SCHEDULED', 'DELAYED', 'BOARDING', etc.
    DateTime? departureTime, // Новое время вылета (опционально, для DELAYED)
    DateTime? arrivalTime,   // Новое время прилёта (опционально, для DELAYED)
    String? gate, // Новый gate (опционально)
  }) async {
    final Map<String, dynamic> body = {
      'status': status,
    };
    if (departureTime != null) {
      body['departure_time'] = departureTime.toUtc().toIso8601String();
    }
    if (arrivalTime != null) {
      body['arrival_time'] = arrivalTime.toUtc().toIso8601String();
    }
    if (gate != null) {
      body['gate'] = gate;
    }
    
    final response = await http.patch(
      Uri.parse('$baseUrl/flights/$flightId'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final responseBody = response.body;
      if (responseBody.isEmpty) {
        throw Exception('Empty response from server');
      }
      final jsonData = jsonDecode(responseBody);
      if (jsonData == null) {
        throw Exception('Null response from server');
      }
      return Flight.fromJson(jsonData);
    } else {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to update flight status');
    }
  }

  // Получить все бронирования (для STAFF)
  static Future<List<Booking>> getAllBookings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/bookings/all'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      final List<Booking> bookings = [];
      for (final json in data) {
        try {
          // Пропускаем бронирования без рейса
          if (json['flight'] == null) continue;
          bookings.add(Booking.fromJson(json));
        } catch (e) {
          print('Error parsing Booking in getAllBookings: $e');
          continue;
        }
      }
      return bookings;
    } else {
      throw Exception('Failed to load bookings: ${response.statusCode}');
    }
  }

  // Получить бронирования по рейсу (для STAFF)
  static Future<List<Booking>> getFlightBookings(int flightId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/flights/$flightId/bookings'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((json) => Booking.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load flight bookings');
    }
  }

  // Создать объявление (для STAFF) - отправляется пассажирам указанного рейса
  static Future<Announcement> createAnnouncement({
    required String title,
    required String content,
    int? flightId,  // Опционально - можно отправить объявление всем пассажирам
  }) async {
    final Map<String, dynamic> requestBody = {
      'title': title,
      'content': content,
    };
    
    // Добавляем flight_id только если указан
    if (flightId != null) {
      requestBody['flight_id'] = flightId;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/announcements'),
      headers: await _getHeaders(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 201) {
      final responseBody = utf8.decode(response.bodyBytes);
      return Announcement.fromJson(jsonDecode(responseBody));
    } else {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to create announcement');
    }
  }

  /// Создание уведомления для пассажиров рейса (STAFF)
  /// Возвращает void — экран не использует тело ответа, нам важен только успех/ошибка.
  static Future<void> createNotification({
    required String title,
    required String content,
    int? flightId,  // Если указан - отправляет всем пассажирам этого рейса
    int? userId,    // Если указан - отправляет только этому пользователю
  }) async {
    final Map<String, dynamic> requestBody = {
      'title': title,
      'content': content,
    };
    
    // Добавляем опциональные поля
    if (flightId != null) {
      requestBody['flight_id'] = flightId;
    }
    if (userId != null) {
      requestBody['user_id'] = userId;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/notifications'),
      headers: await _getHeaders(),
      body: jsonEncode(requestBody),
    );

    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode == 200 || response.statusCode == 201) {
      // Бэкенд возвращает {sent: N, ...}. Нам достаточно успешного статуса.
      debugPrint('Notification sent OK: $body');
      return;
    }

    try {
      final error = jsonDecode(body);
      throw Exception(error['detail'] ?? 'Failed to create notification');
    } catch (_) {
      throw Exception('Failed to create notification: ${response.statusCode}');
    }
  }

  // Создать аэропорт (для STAFF)
  static Future<Airport> createAirport({
    required String code,
    required String name,
    required String city,
    required String country,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/airports'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'code': code,
        'name': name,
        'city': city,
        'country': country,
      }),
    );

    if (response.statusCode == 201) {
      final responseBody = utf8.decode(response.bodyBytes);
      return Airport.fromJson(jsonDecode(responseBody));
    } else {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to create airport');
    }
  }

  // Получить список всех пассажиров (для STAFF)
  static Future<List<PassengerInfo>> getAllPassengers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/passengers'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((json) => PassengerInfo.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load passengers');
    }
  }

  // Получить мои уведомления (для пассажиров)
  static Future<List<AppNotification>> getMyNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(body);
      return data.map((json) => AppNotification.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  // Получить все уведомления (для STAFF)
  static Future<List<AppNotification>> getAllNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/all'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((json) => AppNotification.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load all notifications');
    }

  }

  // ============================================
  // БРОНИРОВАНИЯ (Отмена)
  // ============================================

  static Future<void> cancelBooking(int bookingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/cancel'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      try {
        final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
        throw Exception(error['detail'] ?? 'Failed to cancel booking');
      } catch (e) {
         throw Exception('Failed to cancel booking: ${response.statusCode}');
      }
    }
  }

  // Добавить данные пассажира для места
  static Future<void> submitPassengerForSeat({
    required int seatId,
    required int bookingId,
    required String fullName,
    required DateTime birthDate,
    required String documentNumber,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/seats/$seatId/passenger?booking_id=$bookingId'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'full_name': fullName,
        'birth_date': birthDate.toIso8601String(),
        'document_number': documentNumber,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to submit passenger data');
    }
  }

  // Подтвердить бронирование (проверка данных всех пассажиров)
  static Future<void> confirmBooking(int bookingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bookings/$bookingId/confirm'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Booking confirmation failed');
    }
  }

  // Создать нового сотрудника (только для staff)
  static Future<void> createStaff({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/staff/create-staff');
    final headers = await _getHeaders();
    final body = jsonEncode({
      'email': email,
      'password': password,
    });
    
    debugPrint('=== CREATE STAFF REQUEST ===');
    debugPrint('URL: $url');
    debugPrint('Headers: $headers');
    debugPrint('Body: $body');
    debugPrint('===========================');
    
    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode != 201) {
      final responseBody = utf8.decode(response.bodyBytes);
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to create staff');
    }
  }

  // Создать нового сотрудника (только для существующих staff)
  static Future<void> createStaff({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$baseUrl/staff/create-staff');
    final headers = await _getHeaders();
    final body = jsonEncode({
      'email': email,
      'password': password,
    });

    final response = await http.post(
      url,
      headers: headers,
      body: body,
    );

    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode != 201) {
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Failed to create staff');
    }
  }

  // ============================================
  // STAFF BOOKING MANAGEMENT
  // ============================================

  // Поиск бронирования по PNR (для STAFF)
  static Future<Booking> searchBookingByPnr(String pnr) async {
    final response = await http.get(
      Uri.parse('$baseUrl/staff/bookings/search?pnr=${Uri.encodeComponent(pnr)}'),
      headers: await _getHeaders(),
    );

    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return Booking.fromJson(jsonDecode(responseBody));
    } else {
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Бронирование не найдено');
    }
  }

  // Отмена бронирования сотрудником (для STAFF)
  static Future<void> staffCancelBooking(int bookingId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/staff/bookings/$bookingId/cancel'),
      headers: await _getHeaders(),
    );

    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode != 200) {
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Не удалось отменить бронирование');
    }
  }

  // Переназначение места сотрудником (для STAFF)
  static Future<Map<String, dynamic>> staffReassignSeat({
    required int bookingId,
    required int ticketId,
    required int newSeatId,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/staff/bookings/$bookingId/reassign-seat'),
      headers: await _getHeaders(),
      body: jsonEncode({
        'ticket_id': ticketId,
        'new_seat_id': newSeatId,
      }),
    );

    final responseBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 200) {
      return jsonDecode(responseBody);
    } else {
      final error = jsonDecode(responseBody);
      throw Exception(error['detail'] ?? 'Не удалось переназначить место');
    }
  }

  // Получить бронирования для конкретного рейса (для STAFF)
  static Future<List<Booking>> getBookingsByFlight(int flightId) async {
    // Используем существующий метод getAllBookings и фильтруем
    final allBookings = await getAllBookings();
    return allBookings.where((b) => b.flight.id == flightId).toList();
  }
}

