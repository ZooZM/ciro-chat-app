import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/helpers/responsive.dart';

class DialpadScreen extends StatefulWidget {
  const DialpadScreen({super.key});

  @override
  State<DialpadScreen> createState() => _DialpadScreenState();
}

class _DialpadScreenState extends State<DialpadScreen> {
  String _number = '';
  static const int _maxDigits = 15;

  void _onKeyPress(String key) {
    if (_number.length < _maxDigits) {
      setState(() => _number += key);
    }
  }

  void _onBackspace() {
    if (_number.isNotEmpty) {
      setState(() => _number = _number.substring(0, _number.length - 1));
    }
  }

  Widget _buildDialButton(String digit) {
    return GestureDetector(
      onTap: () => _onKeyPress(digit),
      child: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 231, 231, 231),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          digit,
          style: AppTypography.headline1.copyWith(
            fontSize: 40.resSp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF575656),
            height: 1.0,
          ),
        ),
      ),
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
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.resW),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _number,
                        style: AppTypography.headline1.copyWith(
                          fontSize: 36.resSp,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                    if (_number.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: _onBackspace,
                        color: Colors.grey[600],
                        iconSize: 28.resW,
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 7,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 40.resW),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16.resH,
                  crossAxisSpacing: 24.resW,
                  childAspectRatio: 1.0,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildDialButton('1'),
                    _buildDialButton('2'),
                    _buildDialButton('3'),
                    _buildDialButton('4'),
                    _buildDialButton('5'),
                    _buildDialButton('6'),
                    _buildDialButton('7'),
                    _buildDialButton('8'),
                    _buildDialButton('9'),
                    _buildDialButton('*'),
                    _buildDialButton('0'),
                    _buildDialButton('#'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 32.resH),
              child: SizedBox(
                width: 72.resW,
                height: 72.resW,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF4CAF50),
                  onPressed: () {},
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: Icon(Icons.call, color: Colors.white, size: 32.resW),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
