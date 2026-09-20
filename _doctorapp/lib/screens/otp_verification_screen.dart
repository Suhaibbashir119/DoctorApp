import 'dart:async';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/dtos.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _timer;
  int _startSeconds = 0;
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() {
      _startSeconds = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_startSeconds <= 1) {
        timer.cancel();
        setState(() {
          _startSeconds = 0;
        });
      } else {
        setState(() {
          _startSeconds--;
        });
      }
    });
  }

  Future<void> _onResendCodePressed() async {
    if (_startSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await apiClient.post(
        ApiEndpoints.requestOtp,
        body: {'mobileNumber': widget.phoneNumber},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP Code resent successfully!'),
          backgroundColor: AppTheme.primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );

      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _onVerifyPressed() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter all 4 digits of the OTP.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await apiClient.post(
        ApiEndpoints.confirmOtp,
        body: {
          'key': widget.verificationId,
          'otp': otp,
          'mobileNumber': widget.phoneNumber,
        },
      );

      final dto = ConfirmOtpDto.fromJson(response);

      if (dto.token != null && dto.token!.isNotEmpty) {
        currentAuthToken = dto.token;
      }

      final fullInfo = dto.fullInformation;
      if (fullInfo != null) {
        final name = '${fullInfo['FullName'] ?? fullInfo['UserName'] ?? fullInfo['name'] ?? ''}'.trim();
        if (name.isNotEmpty) {
          currentDoctorName = name.startsWith('Dr.') ? name : 'Dr. $name';
        }
      }

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPhone = widget.phoneNumber.contains('+')
        ? widget.phoneNumber
        : '+91 ${widget.phoneNumber}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Header Badge & Security Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'AUTHENTICATION',
                      style: TextStyle(
                        color: AppTheme.primaryDarkGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.verified_user,
                    color: AppTheme.primaryDarkGreen,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Lock Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_open,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 24),

              // Title & Subtitle
              const Text(
                'Verify Mobile Number',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                  children: [
                    const TextSpan(text: "We've sent a 4-digit verification code to "),
                    TextSpan(
                      text: displayPhone,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 4 Box OTP Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 58,
                    height: 60,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: AppTheme.primaryGreen, width: 2),
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Resend Code Link with Timer
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Didn't receive the code? ",
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: (_startSeconds == 0 && !_isResending)
                          ? _onResendCodePressed
                          : null,
                      child: Text(
                        _isResending
                            ? 'Resending...'
                            : _startSeconds > 0
                                ? 'Resend Code in ${_startSeconds}s'
                                : 'Resend Code',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: (_startSeconds == 0 && !_isResending)
                              ? AppTheme.primaryGreen
                              : AppTheme.textSecondary,
                          decoration: (_startSeconds == 0 && !_isResending)
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Verify & Continue Button
              ElevatedButton(
                onPressed: _isLoading ? null : _onVerifyPressed,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isLoading ? 'Verifying...' : 'Verify & Continue'),
                    const SizedBox(width: 8),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ABDM Footer
              const Center(
                child: Text(
                  'ABDM & HIPAA Encrypted Health Gateway',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
