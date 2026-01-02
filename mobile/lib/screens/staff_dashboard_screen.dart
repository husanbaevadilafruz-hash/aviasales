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
import 'airports_list_screen.dart';

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
            icon: Icons.list_alt,
            title: 'Список аэропортов',
            color: Colors.deepOrange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AirportsListScreen()),
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
            title: 'Добавить сотрудника',
            color: Colors.brown,
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
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Добавить сотрудника'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (логин)',
                        border: OutlineInputBorder(),
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
                      ),
                      obscureText: true,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Подтвердите пароль',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      enabled: !isLoading,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          // Валидация
                          if (emailController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Введите email'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (passwordController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Введите пароль'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (passwordController.text != confirmPasswordController.text) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Пароли не совпадают'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isLoading = true;
                          });

                          try {
                            await ApiService.createStaff(
                              email: emailController.text.trim(),
                              password: passwordController.text,
                            );

                            if (context.mounted) {
                              Navigator.of(dialogContext).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Сотрудник успешно создан'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ошибка: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setState(() {
                                isLoading = false;
                              });
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
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

