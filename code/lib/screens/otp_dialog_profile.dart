import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class OTPDialog extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final String pincode;
  final String villageName;
  final String district;
  final String requestId;
  final List<String> topicOfInterests;
  final Widget nextPage;

  const OTPDialog({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.pincode,
    required this.villageName,
    required this.district,
    required this.topicOfInterests,
    required this.requestId,
    required this.nextPage,
  });

  @override
  State<OTPDialog> createState() => _OTPDialogState();
}

class _OTPDialogState extends State<OTPDialog> {
  final TextEditingController otpController = TextEditingController();
  final ApiService apiService = ApiService();
  bool isLoading = false;

  int countdown = 30;
  bool canResend = false;
  Timer? timer;

  late String currentReqId;

  @override
  void initState() {
    super.initState();
    currentReqId = widget.requestId;
    startTimer();
  }


  @override
  void dispose() {
    timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  void startTimer() {
    countdown = 30;
    canResend = false;
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 0) {
        setState(() {
          countdown--;
        });
      } else {
        setState(() {
          canResend = true;
        });
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOTP() async {
    if (otpController.text.length != 4) {
       _showSnackBar('Enter a valid 4-digit OTP');
      return;
    }

    setState(() {
      isLoading = true;
    });
    try {
    bool success = await apiService.verifyOTP(widget.requestId, otpController.text);
    
    if (success) {
       await apiService.updateUserProfile(
        fullName: widget.fullName,
          phoneNo: widget.phoneNumber,
          pincode: widget.pincode,
          villageName: widget.villageName,
          district: widget.district,
          topicOfInterests: widget.topicOfInterests,
      );
       if (!mounted) return;

      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextPage), 
      );

      _showSnackBar('Profile Updated successfully!');

      
    } else {
      _showSnackBar('Invalid OTP, please try again.');
    }
  } catch (e) {
    _showSnackBar(e.toString());
  }

   

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _resendOTP() async {
  if (canResend) {
    try {
      String? newReqId = await apiService.sendOTP(widget.phoneNumber);
      if (newReqId != null) {
        setState(() {
        currentReqId = newReqId; 
        });
        _showSnackBar('OTP resent successfully');
        startTimer();
      } else {
        _showSnackBar("Failed to resend OTP");
      }
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }
}


  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: otpController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: const InputDecoration(
              hintText: 'Enter OTP',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: canResend ? _resendOTP : null,
            child: Text(
              canResend ? 'Resend OTP' : 'Resend OTP in $countdown s',
              style: TextStyle(color: canResend ? Colors.blue : Colors.grey),
            ),
          ),
        ],
      ),
      actions: [
        isLoading
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: _verifyOTP,
                child: const Text('Verify'),
              ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}