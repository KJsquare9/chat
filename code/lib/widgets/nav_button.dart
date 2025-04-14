import 'package:flutter/material.dart';

class NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  const NavButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: IconButton(
        icon: Icon(
          icon,
          color: isActive ? const Color(0xFFFF5002) : Colors.blue[800],
          size: MediaQuery.of(context).size.width * 0.08,
        ),
        onPressed: onPressed,
      ),
    );
  }
}
