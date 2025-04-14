import 'package:flutter/material.dart';
import 'question_review.dart'; // Import the QuestionReviewScreen
import 'otp_dialog_ayn.dart'; // Import the OTPDialog
import 'ask.dart'; // Import the AskScreen
import '../services/api_service.dart';

void main() {
  runApp(
    MaterialApp(home: AskYourNetaScreen(), debugShowCheckedModeBanner: false),
  );
}

class AskYourNetaScreen extends StatelessWidget {
  AskYourNetaScreen({super.key});
  final TextEditingController nameController = TextEditingController();
  final TextEditingController constituencyController = TextEditingController();
  final TextEditingController questionController = TextEditingController();

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
            name: nameController.text,
            constituency: constituencyController.text,
            question: questionController.text,
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
          icon: Icon(Icons.arrow_back, color: Color(0xFF093466)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo
            Image.asset('assets/images/logo.png', height: 80),
            SizedBox(height: 10),
            Text(
              "Ask Your Neta",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF093466),
              ),
            ),
            SizedBox(height: 20),

            // Search Section
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Color(0xFF093466).withAlpha(205),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: nameController, // Assign controller
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "Search by Name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: Icon(Icons.search, color: Color(0xFF093466)),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "or",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: constituencyController, // Assign controller
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "Search by Constituency",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: Icon(Icons.search, color: Color(0xFF093466)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Question Section
            Container(
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Color(0xFF093466).withAlpha(205),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: questionController, // Assign controller
                maxLines: 3,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Type your Question here",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixIcon: Icon(Icons.chat, color: Color(0xFF093466)),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Buttons
            ElevatedButton(
              onPressed: () {
                // Navigate to ReviewQuestionScreen and pass the values
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ReviewQuestionScreen(
                          name: nameController.text,
                          constituency: constituencyController.text,
                          question: questionController.text,
                        ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF5002),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                "REVIEW YOUR QUESTION",
                style: TextStyle(color: Colors.white),
              ),
            ),
            SizedBox(height: 10),
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
          ],
        ),
      ),
    );
  }
}
