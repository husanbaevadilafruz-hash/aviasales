// models.dart - Модели данных для Flutter

// Этот файл описывает структуру данных, которые приходят от API.
// Каждый класс - это "форма" для данных.

// Например, когда API возвращает информацию о рейсе,
// мы превращаем JSON в объект Flight.

/// Парсит время из строки, предполагая что оно в UTC
/// Сервер возвращает время без 'Z', поэтому добавляем его
DateTime _parseUtcDateTime(String dateTimeStr) {
  // Если строка не заканчивается на 'Z', добавляем
  if (!dateTimeStr.endsWith('Z')) {
    dateTimeStr = '${dateTimeStr}Z';
  }
  return DateTime.parse(dateTimeStr);
}

class User {
  final String email;
  final String role;
  final String? token;

  User({
    required this.email,
    required this.role,
    this.token,
  });

  // Превращаем JSON (от API) в объект User
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      token: json['access_token'],
    );
  }

  // Проверка, является ли пользователь STAFF
  bool get isStaff => role == 'STAFF';
  
  // Проверка, является ли пользователь пассажиром
  bool get isPassenger => role == 'PASSENGER';
}

class Airport {
  final int id;
  final String code;
  final String name;
  final String city;
  final String country;

  Airport({
    required this.id,
    required this.code,
    required this.name,
    required this.city,
    required this.country,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    try {
      return Airport(
        id: json['id'] as int,
        code: json['code'] as String? ?? 'UNKNOWN',
        name: json['name'] as String? ?? 'Unknown Airport',
        city: json['city'] as String? ?? 'Unknown City',
        country: json['country'] as String? ?? 'Unknown Country',
      );
    } catch (e) {
      print('Error parsing Airport: $e');
      print('JSON: $json');
      rethrow;
    }
  }
}

class Airplane {
  final int id;
  final String model;
  final int totalSeats;

  Airplane({
    required this.id,
    required this.model,
    required this.totalSeats,
  });

  factory Airplane.fromJson(Map<String, dynamic> json) {
    return Airplane(
      id: json['id'],
      model: json['model'],
      totalSeats: json['total_seats'],
    );
  }
}

class Flight {
  final int id;
  final String flightNumber;
  final Airport departureAirport;
  final Airport arrivalAirport;
  final DateTime departureTime;
  final DateTime arrivalTime;
  final int airplaneId;
  final String status;
  final double basePrice;
  final String gate;

  Flight({
    required this.id,
    required this.flightNumber,
    required this.departureAirport,
    required this.arrivalAirport,
    required this.departureTime,
    required this.arrivalTime,
    required this.airplaneId,
    required this.status,
    required this.basePrice,
    required this.gate,
  });

  factory Flight.fromJson(Map<String, dynamic> json) {
    try {
      final idValue = json['id'];
      if (idValue == null) {
        throw FormatException('id is required but was null in Flight JSON');
      }
      
      return Flight(
        id: idValue as int,
        flightNumber: json['flight_number'] as String? ?? 'UNKNOWN',
        departureAirport: Airport.fromJson(json['departure_airport'] as Map<String, dynamic>),
        arrivalAirport: Airport.fromJson(json['arrival_airport'] as Map<String, dynamic>),
        departureTime: DateTime.parse(json['departure_time'] as String),
        arrivalTime: DateTime.parse(json['arrival_time'] as String),
        airplaneId: json['airplane_id'] as int,
        status: json['status'] as String? ?? 'UNKNOWN',
        basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
        gate: json['gate'] as String? ?? '',
      );
    } catch (e) {
      print('Error parsing Flight: $e');
      print('JSON: $json');
      rethrow;
    }
  }
}

class Seat {
  final int id;
  final int airplaneId;
  final String seatNumber;
  final String status;
  final String category; // STANDARD / EXTRA_LEGROOM
  final DateTime? heldUntil;

  Seat({
    required this.id,
    required this.airplaneId,
    required this.seatNumber,
    required this.status,
    required this.category,
    this.heldUntil,
  });

  factory Seat.fromJson(Map<String, dynamic> json) {
    try {
      return Seat(
        id: json['id'] as int,
        airplaneId: json['airplane_id'] as int,
        seatNumber: json['seat_number'] as String,
        status: json['status'] as String? ?? 'AVAILABLE',
        category: json['category'] as String? ?? 'STANDARD',
        heldUntil: json['held_until'] != null
            ? DateTime.parse(json['held_until'] as String)
            : null,
      );
    } catch (e) {
      print('Error parsing Seat: $e');
      print('JSON: $json');
      rethrow;
    }
  }

  bool get isAvailable => status == 'AVAILABLE';
  bool get isHeld => status == 'HELD';
  bool get isBooked => status == 'BOOKED';
}

class SeatMap {
  final int flightId;
  final List<Seat> seats;

  SeatMap({
    required this.flightId,
    required this.seats,
  });

  factory SeatMap.fromJson(Map<String, dynamic> json) {
    return SeatMap(
      flightId: json['flight_id'],
      seats: (json['seats'] as List)
          .map((seat) => Seat.fromJson(seat))
          .toList(),
    );
  }
}

class Booking {
  final int id;
  final Flight flight;
  final String status; // CREATED, CONFIRMED, CANCELLED
  final String pnr; // Код бронирования (6 символов)
  final List<Ticket> tickets;
  final List<Payment> payments;
  final DateTime createdAt;

  Booking({
    required this.id,
    required this.flight,
    required this.status,
    required this.pnr,
    required this.tickets,
    required this.payments,
    required this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    try {
      return Booking(
        id: json['id'] as int,
        flight: Flight.fromJson(json['flight'] as Map<String, dynamic>),
        status: json['status'] as String? ?? 'UNKNOWN',
        pnr: json['pnr'] as String? ?? '',
        tickets: (json['tickets'] as List?)
                ?.map((ticket) => Ticket.fromJson(ticket as Map<String, dynamic>))
                .toList() ??
            [],
        payments: (json['payments'] as List?)
                ?.map((payment) => Payment.fromJson(payment as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: _parseUtcDateTime(json['created_at'] as String),
      );
    } catch (e) {
      print('Error parsing Booking: $e');
      print('JSON: $json');
      rethrow;
    }
  }

  // Проверка, истекло ли время ожидания оплаты
  // Бронирование истекает, если статус CREATED и прошло более 10 минут с created_at
  bool get isExpired {
    if (status != 'CREATED') return false;
    
    final now = DateTime.now().toUtc();
    final timeDiff = now.difference(createdAt);
    return timeDiff > const Duration(minutes: 10);
  }

  // Получить оставшееся время до истечения (в секундах)
  // Возвращает 0, если время истекло или статус не CREATED
  int get secondsRemaining {
    if (status != 'CREATED') return 0;
    
    final now = DateTime.now().toUtc();
    final expirationTime = createdAt.add(const Duration(minutes: 10));
    final remaining = expirationTime.difference(now);
    
    print('[Timer Debug] Booking ID: $id');
    print('[Timer Debug] createdAt (UTC): $createdAt');
    print('[Timer Debug] expirationTime (UTC): $expirationTime');
    print('[Timer Debug] now (UTC): $now');
    print('[Timer Debug] remaining seconds: ${remaining.inSeconds}');
    
    return remaining.inSeconds > 0 ? remaining.inSeconds : 0;
  }

  // Проверка, ожидается ли оплата
  bool get isPendingPayment => status == 'CREATED';
}

class Ticket {
  final int id;
  final int bookingId;
  final Seat seat;
  final String? fullName;
  final String? ticketNumber;
  final CheckIn? checkIn;

  Ticket({
    required this.id,
    required this.bookingId,
    required this.seat,
    this.fullName,
    this.ticketNumber,
    this.checkIn,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    try {
      return Ticket(
        id: json['id'] as int,
        bookingId: json['booking_id'] as int,
        seat: Seat.fromJson(json['seat'] as Map<String, dynamic>),
        fullName: json['full_name'] as String?,
        ticketNumber: json['ticket_number'] as String?,
        checkIn: json['check_in'] != null
            ? CheckIn.fromJson(json['check_in'] as Map<String, dynamic>)
            : null,
      );
    } catch (e) {
      print('Error parsing Ticket: $e');
      print('JSON: $json');
      rethrow;
    }
  }
}

class CheckIn {
  final int id;
  final int ticketId;
  final String boardingPassNumber;
  final DateTime checkedInAt;

  CheckIn({
    required this.id,
    required this.ticketId,
    required this.boardingPassNumber,
    required this.checkedInAt,
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as int,
      boardingPassNumber: json['boarding_pass_number'] as String,
      checkedInAt: DateTime.parse(json['checked_in_at'] as String),
    );
  }
}

class BoardingPass {
  final String passengerName;
  final String flightNumber;
  final String seat;
  final String gate;
  final DateTime boardingTime;
  final String qrPayload;
  final String boardingPassNumber;

  BoardingPass({
    required this.passengerName,
    required this.flightNumber,
    required this.seat,
    required this.gate,
    required this.boardingTime,
    required this.qrPayload,
    required this.boardingPassNumber,
  });

  factory BoardingPass.fromJson(Map<String, dynamic> json) {
    return BoardingPass(
      passengerName: json['passenger_name'] as String,
      flightNumber: (json['flight']?['flight_number'] as String?) ?? '',
      seat: json['seat_number'] as String,
      gate: json['gate'] as String? ?? '',
      boardingTime: DateTime.parse(json['boarding_time'] as String),
      qrPayload: json['qr_payload'] as String,
      boardingPassNumber: json['boarding_pass_number'] as String,
    );
  }
}

class Announcement {
  final int id;
  final String title;
  final String content;
  final int flightId;
  final DateTime createdAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.flightId,
    required this.createdAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    // Проверяем что flight_id не null, так как это обязательное поле
    final flightIdValue = json['flight_id'];
    if (flightIdValue == null) {
      throw FormatException('flight_id is required but was null in Announcement JSON');
    }
    
    return Announcement(
      id: json['id'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      flightId: flightIdValue as int, // Теперь гарантированно не null
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PassengerProfile {
  final int id;
  final int userId;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String passportNumber;
  final String? phone;
  final String? nationality;

  PassengerProfile({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.passportNumber,
    this.phone,
    this.nationality,
  });

  factory PassengerProfile.fromJson(Map<String, dynamic> json) {
    return PassengerProfile(
      id: json['id'],
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      passportNumber: json['passport_number'],
      phone: json['phone'],
      nationality: json['nationality'],
    );
  }
}

class PassengerInfo {
  final int userId;
  final String email;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String passportNumber;
  final String? phone;
  final String? nationality;
  final DateTime createdAt;

  PassengerInfo({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.passportNumber,
    this.phone,
    this.nationality,
    required this.createdAt,
  });

  factory PassengerInfo.fromJson(Map<String, dynamic> json) {
    return PassengerInfo(
      userId: json['user_id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      dateOfBirth: DateTime.parse(json['date_of_birth']),
      passportNumber: json['passport_number'],
      phone: json['phone'],
      nationality: json['nationality'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class AppNotification {
  final int id;
  final int userId;
  final int? flightId;
  final String title;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    this.flightId,
    required this.title,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      flightId: json['flight_id'],
      title: json['title'],
      content: json['content'],
      isRead: json['is_read'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class PassengerPerSeat {
  final int id;
  final int seatId;
  final int bookingId;
  final String fullName;
  final DateTime birthDate;
  final String documentNumber;
  final String? nationality;
  final String? phone;
  final String? email;

  PassengerPerSeat({
    this.id = 0,
    this.seatId = 0,
    this.bookingId = 0,
    required this.fullName,
    required this.birthDate,
    required this.documentNumber,
    this.nationality,
    this.phone,
    this.email,
  });

  factory PassengerPerSeat.fromJson(Map<String, dynamic> json) {
    return PassengerPerSeat(
      id: json['id'],
      seatId: json['seat_id'],
      bookingId: json['booking_id'],
      fullName: json['full_name'],
      birthDate: DateTime.parse(json['birth_date']),
      documentNumber: json['document_number'],
      nationality: json['nationality'],
      phone: json['phone'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'birth_date': birthDate.toIso8601String(),
      'document_number': documentNumber,
      'nationality': nationality,
      'phone': phone,
      'email': email,
    };
  }
}

class Payment {
  final int id;
  final int bookingId;
  final double amount;
  final String method;
  final String status;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    try {
      return Payment(
        id: json['id'] as int,
        bookingId: json['booking_id'] as int,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        method: json['method'] as String? ?? 'UNKNOWN',
        status: json['status'] as String? ?? 'UNKNOWN',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
    } catch (e) {
      print('Error parsing Payment: $e');
      print('JSON: $json');
      rethrow;
    }
  }
}