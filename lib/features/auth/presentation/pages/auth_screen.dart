import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_cubit.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpMode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth Test UI'),
        centerTitle: true,
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
          if (state is Unauthenticated && _phoneController.text.isNotEmpty) {
            // Automatically switch to OTP mode if we just sent the phone number
            setState(() => _isOtpMode = true);
          }
          if (state is AuthInitial) {
              setState(() => _isOtpMode = false);
          }
        },
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is Authenticated) {
            return _buildAuthenticatedUI();
          }

          if (_isOtpMode || state is Unauthenticated) {
            return _buildOtpInputUI();
          }

          return _buildPhoneInputUI();
        },
      ),
    );
  }

  Widget _buildPhoneInputUI() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Enter your phone number',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+20 123 456 7890',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final phone = _phoneController.text.trim();
                if (phone.isNotEmpty) {
                  context.read<AuthCubit>().submitPhoneNumber(phone);
                }
              },
              child: const Text('Send OTP'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInputUI() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Enter OTP sent to ${_phoneController.text}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: '6-Digit OTP',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final otp = _otpController.text.trim();
                if (otp.length == 6) {
                  context.read<AuthCubit>().submitOtp(
                        _phoneController.text.trim(),
                        otp,
                      );
                }
              },
              child: const Text('Verify'),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isOtpMode = false;
                _otpController.clear();
              });
            },
            child: const Text('Change Phone Number'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticatedUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '✅',
            style: TextStyle(fontSize: 100),
          ),
          const SizedBox(height: 20),
          const Text(
            'Authenticated Successfully!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(220, 50),
            ),
            onPressed: () => context.push('/video_call'),
            icon: const Icon(Icons.video_call),
            label: const Text('Go to Video Call'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(220, 50),
            ),
            onPressed: () {
              context.read<AuthCubit>().logOut();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
