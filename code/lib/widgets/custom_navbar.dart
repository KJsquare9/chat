import 'package:flutter/material.dart';
import '../screens/news_feed_screen.dart';
import '../screens/marketplace_page.dart';
import '../screens/chats_list.dart';
import '../screens/settings.dart';
import '../screens/ask.dart';

class CustomNavBar extends StatefulWidget {
  final int activeIndex;

  const CustomNavBar({super.key, required this.activeIndex});

  @override
  CustomNavBarState createState() => CustomNavBarState();
}

class CustomNavBarState extends State<CustomNavBar> {
  List<bool> hasNotifications = [false, false, false, false, false];

  // Method to update notifications from outside widget
  void updateNotification(int index, bool newValue) {
    setState(() {
      hasNotifications[index] = newValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((0.6 * 255).toInt()),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavBarItem(context, Icons.article, 0, NewsFeedScreen(),
              hasNotifications[0]),
          _buildNavBarItem(context, Icons.people, 1, AskScreen(),
              hasNotifications[1]),
          _buildNavBarItem(context, Icons.store, 2, MarketplacePage(),
              hasNotifications[2]),
          _buildNavBarItem(context, Icons.chat, 3, const ChatListPage(),
              hasNotifications[3]),
          _buildNavBarItem(
              context, Icons.settings, 4, const AppSettingsScreen(), hasNotifications[4]),
        ],
      ),
    );
  }

  Widget _buildNavBarItem(BuildContext context, IconData icon, int index,
      Widget screen, bool hasNotification) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: widget.activeIndex == index
                ? const Color(0xFFFF5002)
                : const Color(0xFF093466),
            size: MediaQuery.of(context).size.width * 0.08,
          ),
          onPressed: () {
            if (widget.activeIndex != index) {
              setState(() {
                hasNotifications[index] = false;
              });
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => screen),
              );
            }
          },
        ),
        if (hasNotification)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.deepOrange,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(
                minWidth: 12,
                minHeight: 12,
              ),
            ),
          ),
      ],
    );
  }
}