import 'package:flutter/material.dart';
import 'flight_search_screen.dart';
import 'my_trips_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  static final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

  MainScreen({this.initialIndex = 0}) : super(key: mainScreenKey);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  final GlobalKey<MyTripsScreenState> _myTripsKey = GlobalKey<MyTripsScreenState>();
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Создаём список экранов один раз при инициализации
    _screens = [
      const FlightSearchScreen(),
      MyTripsScreen(key: _myTripsKey),
      const ProfileScreen(),
    ];
  }

  void setIndex(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Если переключаемся на "Мои поездки", обновляем список
    if (index == 1) {
      Future.delayed(const Duration(milliseconds: 100), () {
        refreshBookings();
      });
    }
  }

  void refreshBookings() {
    // Перезагружаем список бронирований
    debugPrint('[MainScreen] Refreshing bookings...');
    _myTripsKey.currentState?.refreshBookings();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: const Color(0xFF6B46C1),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 8,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.airplane_ticket),
              label: 'My Trips',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
