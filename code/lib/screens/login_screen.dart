import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/signup_screen.dart';
import '../screens/otp_dialog.dart';
import '../screens/news_feed_screen.dart'; // Import the NewsFeedScreen
import '../services/api_service.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController phoneController = TextEditingController();
   final ApiService apiService = ApiService();
    bool isLoading = false;

Future<void> _sendOTP() async {
  if (phoneController.text.length != 10) {
    _showSnackBar('Please enter a valid 10-digit phone number');
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    String phoneNumber = phoneController.text;
    bool? userExists = await apiService.checkUserExists(phoneNumber);
    if (userExists == true) {
      String? reqId = await apiService.sendOTP(phoneNumber);
      if (reqId != null) {
        _showSnackBar('OTP sent successfully');
        if (!mounted) return;
        _showOTPDialog(context, reqId);
      } else {
        _showSnackBar('Failed to send OTP');
      }
    } else if (userExists == false) {
      _showSnackBar('User not found, please sign up.');
    } else {
      _showSnackBar('Error checking user existence.');
    }
  } catch (e) {
    _showSnackBar(e.toString());
  }

  setState(() {
    isLoading = false;
  });
}

void _showSnackBar(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void _showOTPDialog(BuildContext context, String reqId) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return OTPDialog(
        phoneNumber: phoneController.text,
        reqId: reqId, // Pass reqId to OTPDialog
        nextPage: const NewsFeedScreen(),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', height: 100),
              const SizedBox(height: 20),
              const Text(
                'Login to access your bookmarks and personal preferences.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  hintText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(13, 71, 161, 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (phoneController.text.length == 10) {
                      _sendOTP();
                    } else {
                      _showSnackBar('Please enter a valid 10-digit phone number');
                    }
                  },
                  child: const Text(
                    'LOGIN',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text('or', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5002),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'SIGN UP',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }
}