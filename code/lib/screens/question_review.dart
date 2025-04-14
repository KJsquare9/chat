import 'package:flutter/material.dart';
import 'package:apnagram/screens/ask.dart'; // Ensure this import is correct
import 'package:apnagram/screens/otp_dialog_ayn.dart'; // Ensure this import is correct
import '../services/api_service.dart';

void main() {
  runApp(MaterialApp(
    home: ReviewQuestionScreen(
      name: '',
      constituency: '',
      question: '',
    ),
    debugShowCheckedModeBanner: false,
  ));
}


class ReviewQuestionScreen extends StatelessWidget {
  final String name;
  final String constituency;
  final String question;

  const ReviewQuestionScreen({
    super.key,
    required this.name,
    required this.constituency,
    required this.question,
  });
  void _showOTPDialog(BuildContext context) async {
  final ApiService apiService = ApiService();
  String? phoneNumber = await apiService.getUserPhoneNumber();
  if (phoneNumber != null) {
    String? requestId = await apiService.sendOTP(phoneNumber);
    if (requestId != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return OTPDialog(
            phoneNumber: phoneNumber,
            requestId: requestId, // Pass the request ID to the dialog
            nextPage: const AskScreen(), // Pass AskScreen as nextPage
            name: name,
            constituency: constituency,
            question: question,
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send OTP. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Failed to fetch phone number.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/logo.png', // Ensure this image exists in assets
                height: 80,
              ),
              SizedBox(height: 10),

              // Title
              Text(
                "Review Your Question",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              ),

              // Instruction
              TextButton(
                onPressed: () {}, // Add link functionality if needed
                child: Text(
                  "Confirm the details before you submit your question",
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
              SizedBox(height: 20),

              // Input Fields
              buildInputField("NAME OF NETA", name, Icons.search),
              buildInputField("CONSTITUENCY", constituency, Icons.location_on),
              buildInputField("QUESTION", question, Icons.chat),

              SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  _showOTPDialog(context); // Show OTP dialog on button press
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF5002),
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text("SUBMIT", style: TextStyle(color: Colors.white)),
              ),
              SizedBox(height: 20), // Extra space at the bottom for better scrolling
            ],
          ),
        ),
      ),
    );
  }

  // Widget to build input field
  Widget buildInputField(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        SizedBox(height: 5),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              Icon(icon, color: Colors.white),
            ],
          ),
        ),
        SizedBox(height: 15),
      ],
    );
  }
}