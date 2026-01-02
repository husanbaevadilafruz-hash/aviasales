// staff_dashboard_screen.dart - Главный экран для STAFF (сотрудников)

import 'package:flutter/material.dart';
import '../api_service.dart';
import '../models.dart';
import 'create_airplane_screen.dart';
import 'create_flight_screen.dart';
import 'staff_bookings_screen.dart';
import 'create_announcement_screen.dart';
import 'announcements_screen.dart';
import 'login_screen.dart';
import 'create_airport_screen.dart';
import 'manage_flights_screen.dart';
import 'passengers_list_screen.dart';
import 'all_notifications_screen.dart';
import 'airplanes_list_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  final User user;

  const StaffDashboardScreen({super.key, required this.user});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель сотрудника'),
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildMenuCard(
            icon: Icons.flight_takeoff,
            title: 'Создать самолёт',
            color: Colors.blue,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateAirplaneScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.airplane_ticket,
            title: 'Список самолетов',
            color: Colors.cyan,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AirplanesListScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.airport_shuttle,
            title: 'Создать аэропорт',
            color: Colors.teal,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateAirportScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.flight,
            title: 'Создать рейс',
            color: Colors.green,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateFlightScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.edit_calendar,
            title: 'Управление рейсами',
            color: Colors.indigo,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ManageFlightsScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.confirmation_number,
            title: 'Бронирования',
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StaffBookingsScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.people,
            title: 'Список пассажиров',
            color: Colors.pink,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PassengersListScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.announcement,
            title: 'Создать объявление',
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateAnnouncementScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.notifications_active,
            title: 'Все уведомления',
            color: Colors.red,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AllNotificationsScreen()),
              );
            },
          ),
          _buildMenuCard(
            icon: Icons.person_add,
            title: 'Создать сотрудника',
            color: Colors.deepPurple,
            onTap: () {
              _showCreateStaffDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showCreateStaffDialog(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Создать нового сотрудника'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  enabled: !isLoading,
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                    if (emailController.text.isEmpty ||
                        passwordController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Заполните все поля'),
                        ),
                      );
                      return;
                    }

                    if (passwordController.text.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Пароль должен быть не менее 6 символов'),
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      isLoading = true;
                    });

                    try {
                      await ApiService.createStaff(
                        email: emailController.text.trim(),
                        password: passwordController.text,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Сотрудник ${emailController.text.trim()} успешно создан',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setDialogState(() {
                          isLoading = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', ''),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
              child: const Text('Создать'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

