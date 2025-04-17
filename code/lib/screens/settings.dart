import 'package:flutter/material.dart';
// Assuming CustomNavbar is in this relative path. Adjust if needed.
import '../widgets/custom_navbar.dart';
import 'login_screen.dart'; // Import the LoginScreen
import 'profile_screen.dart'; // Import the profile info screen
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = false;

  void _logout(BuildContext context) async {
    // Store the navigator before the async gap
    final navigator = Navigator.of(context);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token'); // ✅ Remove the token from storage

    // Check if the widget is still mounted before continuing
    if (!mounted) return;

    // Use the stored navigator reference instead of directly using context
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // Removes all previous routes from the stack
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo[900],
        title: const Text(
          'APP SETTINGS',
          style: TextStyle(color: Colors.white, fontSize: 18.0),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'General',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile info'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileInfoScreen(),
                ),
              );
            },
          ),
          const Divider(),
          const Text(
            'Features',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Allow Notifications'),
            trailing: Checkbox(
              value: _notificationsEnabled,
              onChanged: (bool? value) {
                setState(() {
                  _notificationsEnabled = value ?? false;
                });
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Search history'),
            onTap: () {
              Navigator.pushNamed(context, '/search_history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('Buy Premium Plan'),
            onTap: () {
              Navigator.pushNamed(context, '/buy_premium');
            },
          ),
          const Divider(),
          const Text(
            'Services',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Privacy policy'),
            onTap: () {
              Navigator.pushNamed(context, '/privacy_policy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Visit rizo...'),
            onTap: () {
              Navigator.pushNamed(context, '/visit_rizo');
            },
          ),
          ListTile(
            title: const Text('Clear cache'),
            onTap: () {
              Navigator.pushNamed(context, '/clear_cache');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              _logout(context);
            },
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(activeIndex: 4),
    );
  }
}
