import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/verify_code_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/core/error/failures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../mocks.dart';

class MockAuthCubit extends Mock implements AuthCubit {}

void main() {
  late MockAuthCubit mockAuthCubit;

  setUp(() {
    mockAuthCubit = MockAuthCubit();
  });

  Widget createWidgetUnderTest() {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) => MaterialApp(
        home: BlocProvider<AuthCubit>.value(
          value: mockAuthCubit,
          child: const VerifyCodeScreen(phoneNumber: '+1234567890'),
        ),
      ),
    );
  }

  testWidgets('should show SnackBar when state is AuthError', (tester) async {
    // arrange
    const tFailure = AuthFailure('OTP Verification Failed');
    
    // We need to simulate the state transition to AuthError
    when(() => mockAuthCubit.state).thenReturn(const AuthInitial());
    when(() => mockAuthCubit.stream).thenAnswer((_) => Stream.value(const AuthError(tFailure)));

    // act
    await tester.pumpWidget(createWidgetUnderTest());
    
    // Trigger the stream listener by pumping again
    await tester.pump();

    // assert
    expect(find.text('OTP Verification Failed'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}
