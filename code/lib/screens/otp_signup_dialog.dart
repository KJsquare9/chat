import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class OTPDialog extends StatefulWidget {
  final String phoneNumber;
  final String fullName;
  final String pinCode;
  final String villageName;
  final String district;
  final String reqId;
  final List<String> topics;
  final Widget nextPage;

  const OTPDialog({
    super.key,
    required this.phoneNumber,
    required this.fullName,
    required this.pinCode,
    required this.villageName,
    required this.district,
    required this.topics,
    required this.nextPage,
    required this.reqId,
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
    currentReqId = widget.reqId;
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
      bool success = await apiService.verifyOTP(
        widget.reqId,
        otpController.text,
      );

      if (success) {
        await apiService.createUser(
          fullName: widget.fullName,
          phoneNumber: widget.phoneNumber,
          pinCode: widget.pinCode,
          villageName: widget.villageName,
          district: widget.district,
          topics: widget.topics,
        );

        if (!mounted) return;

        // Request notification permissions after successful registration
        await apiService.requestNotificationPermission();

        if (!mounted) return;

        // Store navigation actions before popping
        final navigator = Navigator.of(context);
        navigator.pop();
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextPage),
        );

        _showSnackBar('User registered successfully!');
      } else {
        _showSnackBar('Invalid OTP, please try again.');
      }
    } catch (e) {
      _showSnackBar(e.toString());
    }

    if (!mounted) return;

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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            : TextButton(onPressed: _verifyOTP, child: const Text('Verify')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
