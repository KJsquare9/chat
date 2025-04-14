import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart'; // Import the API service
import '../screens/otp_dialog_profile.dart';


class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({super.key});
  
  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final ApiService apiService = ApiService();
  bool _isEditing = false;
  bool _isLoading = true;
  Map<String, dynamic> _profileData = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Use the imported getUserProfile function
      final data = await apiService.getUserProfile();
      print(data);
      
      setState(() {
        _profileData = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile data';
        _isLoading = false;
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  void _saveProfile(Map<String, String> updatedData) {
    setState(() {
      _profileData.clear();
      _profileData.addAll(updatedData);
      _isEditing = false; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Info'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
            onPressed: _toggleEdit,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _isEditing
                  ? EditProfileScreen(
                      profileData: _profileData,
                      onSave: _saveProfile,
                    )
                  : ProfileDetails(profileData: _profileData),
    );
  }
}

class ProfileDetails extends StatelessWidget {
  final Map<String, dynamic> profileData;

  const ProfileDetails({super.key, required this.profileData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailItem('Name', profileData['Name'] ?? ''),
          _buildDetailItem('Phone Number', profileData['Phone Number'] ?? ''),
          _buildDetailItem('Village Name', profileData['Village Name'] ?? ''),
          _buildDetailItem('Pincode', profileData['Pincode'] ?? ''),
          _buildDetailItem('District Name', profileData['District Name'] ?? ''),
          _buildDetailItem('Topic of Interests', profileData['Topic of Interests'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14.0,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 20.0, thickness: 1.0),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final Function(Map<String, String>) onSave;

  const EditProfileScreen({
    super.key,
    required this.profileData,
    required this.onSave,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Map<String, TextEditingController> _controllers;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controllers = {
      'Name': TextEditingController(text: widget.profileData['Name']),
      'Phone Number': TextEditingController(text: widget.profileData['Phone Number']),
      'Village Name': TextEditingController(text: widget.profileData['Village Name']),
      'Pincode': TextEditingController(text: widget.profileData['Pincode']),
      'District Name': TextEditingController(text: widget.profileData['District Name']),
      'Topic of Interests': TextEditingController(text: widget.profileData['Topic of Interests']),
    };
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }

 void _saveProfile() async {
  if (_formKey.currentState!.validate()) {
    final ApiService apiService = ApiService();
    final String editedPhoneNumber = _controllers['Phone Number']!.text;
    final String originalPhoneNumber = widget.profileData['Phone Number'];
    if (editedPhoneNumber != originalPhoneNumber) {
      bool? userExists = await apiService.checkUserExists(editedPhoneNumber);
      if (userExists == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This phone number is already in use.'),
            backgroundColor: Colors.red,
          ),
        );
        return; 
      }
    }
    try {
      String? requestId = await apiService.sendOTP(editedPhoneNumber);
      if (requestId != null) {
        _showOtpDialog(
          fullName: _controllers['Name']!.text,
          phoneNo: editedPhoneNumber,
          pincode: _controllers['Pincode']!.text,
          villageName: _controllers['Village Name']!.text,
          district: _controllers['District Name']!.text,
          topicOfInterests: _controllers['Topic of Interests']!.text
              .split(',')
              .map((e) => e.trim())
              .toList(),
          requestId: requestId, // Pass the request ID to the dialog
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send OTP. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle any errors that occur during the API call
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  void _showOtpDialog({
  required String fullName,
  required String phoneNo,
  required String pincode,
  required String villageName,
  required String district,
  required String requestId,
  required List<String> topicOfInterests,
}) {
  showDialog(
    context: context,
    builder: (context) {
      return OTPDialog(
        phoneNumber: phoneNo,
        fullName: fullName,
        pincode: pincode,
        villageName: villageName,
        district: district,
        topicOfInterests: topicOfInterests,
        requestId: requestId,
        nextPage: const ProfileInfoScreen(),
      );
    },
  );
}

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(value)) {
      return 'Phone number must be 10 digits';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Pincode is required';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'Pincode must be 6 digits';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField('Name', _controllers['Name']!),
            _buildTextField(
              'Phone Number',
              _controllers['Phone Number']!,
              validator: _validatePhoneNumber,
            ),
            _buildTextField('Village Name', _controllers['Village Name']!),
            _buildTextField(
              'Pincode',
              _controllers['Pincode']!,
              validator: _validatePincode,
            ),
            _buildTextField('District Name', _controllers['District Name']!),
            _buildTextField('Topic of Interests', _controllers['Topic of Interests']!),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF093466),
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
              ),
              child: const Text(
                'SAVE PROFILE',
                style: TextStyle(fontSize: 16.0, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
        controller: controller,
        validator: validator,
      ),
    );
  }
}


