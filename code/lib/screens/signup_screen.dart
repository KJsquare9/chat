import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/otp_signup_dialog.dart';
import '../screens/news_feed_screen.dart'; 
import '../services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController pinCodeController = TextEditingController();
  final TextEditingController villageController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController otherInterestController = TextEditingController();

  final Set<String> selectedTopics = {};
  final List<String> topics = [
    'Finance', 'Weather', 'Politics', 'Education', 'Entertainment',
    'Sports', 'Crime', 'Science & Technology', 'Agriculture'
  ];

  void _showOTPDialog(BuildContext context,String reqId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return OTPDialog(
          phoneNumber: phoneController.text,
          fullName: nameController.text,
          pinCode: pinCodeController.text,
          villageName: villageController.text,
          reqId: reqId, 
          district:districtController.text,
          topics: selectedTopics.toList(),
          nextPage: const NewsFeedScreen(), 
        );
      },
    );
  }

  bool _validateFields() {
    if (nameController.text.isEmpty ||
        phoneController.text.length != 10 ||
        pinCodeController.text.length != 6 ||
        villageController.text.isEmpty ||
        districtController.text.isEmpty) {
        _showSnackBar('Please fill all required fields correctly');
      return false;
    }
    if (selectedTopics.isEmpty) {
       _showSnackBar('Please select at least one topic of interest');
      return false;
    }
    return true;
  }
    final ApiService apiService = ApiService();


  void _registerUser() async {
  if (_validateFields()) {
    try {
    String phoneNumber = phoneController.text;
    bool? userExists = await apiService.checkUserExists(phoneNumber);
    if (userExists == false) {
      String? reqId = await apiService.sendOTP(phoneNumber);
      if (reqId != null) {
        _showSnackBar('OTP sent successfully');
        if (!mounted) return;
        _showOTPDialog(context, reqId);
      } else {
        _showSnackBar('Failed to send OTP');
      }
    } else if (userExists == true) {
      _showSnackBar('User already exists, please log in.');
    } else {
      _showSnackBar('Error checking user existence.');
    }
  } catch (e) {
    _showSnackBar(e.toString());
  }
  }
}

void _showSnackBar(String message) {
  if (!mounted) return; // Check if the widget is still in the tree
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.asset('assets/images/logo.png', height: 100)),
            const SizedBox(height: 20),
            _buildTextField(nameController, 'Name', Icons.person),
            _buildTextField(phoneController, 'Phone Number', Icons.phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
            _buildTextField(pinCodeController, 'Pin Code', Icons.location_on,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
            _buildTextField(villageController, 'Village Name', Icons.home),
            _buildTextField(districtController, 'District Name', Icons.location_city),
            const SizedBox(height: 20),
            const Text('Select topics of interest', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 10,
              children: topics.map((topic) => _buildTopicChip(topic)).toList(),
            ),
            _buildTextField(otherInterestController, 'Other Interest', Icons.category),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5002),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _registerUser,
                child: const Text('SIGN UP', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),
    );
  }

  Widget _buildTopicChip(String topic) {
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTopics.contains(topic) ? selectedTopics.remove(topic) : selectedTopics.add(topic);
        });
      },
      child: Chip(
        label: Text(topic),
        backgroundColor: selectedTopics.contains(topic) ? Colors.blue : Colors.grey[300],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    pinCodeController.dispose();
    villageController.dispose();
    otherInterestController.dispose();
    super.dispose();
  }
}