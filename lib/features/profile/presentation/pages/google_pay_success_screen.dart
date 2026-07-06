import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';

class GooglePaySuccessScreen extends StatelessWidget {
  const GooglePaySuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Simulating the confetti checkmark
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Confetti dots (simple simulation)
                      ...List.generate(12, (index) {
                        final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple];
                        final angle = index * (3.14159 * 2 / 12);
                        return Transform.translate(
                          offset: Offset(80 * const EdgeInsets.all(1).horizontal * (index % 2 == 0 ? 1 : 0.8) * 0.5 * (index.isEven ? 1 : -1), 80 * const EdgeInsets.all(1).vertical * (index % 3 == 0 ? 1 : 0.7)),
                          child: Transform.rotate(
                            angle: angle,
                            child: Container(
                              width: index.isEven ? 8 : 6,
                              height: index.isEven ? 8 : 6,
                              decoration: BoxDecoration(
                                color: colors[index % colors.length],
                                shape: index % 3 == 0 ? BoxShape.rectangle : BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                      // Outer green ring
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CA440),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4CA440).withAlpha(100),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      // Inner white circle
                      Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Check icon
                      const Icon(
                        Icons.check,
                        size: 72,
                        color: Color(0xFF4CA440),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'google_pay_added'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'google_pay_ready_desc'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // Go back to payments method screen
                  context.go(AppRouterName.paymentsMethod);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CA440),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'done'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
