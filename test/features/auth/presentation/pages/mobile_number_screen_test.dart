import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ciro_chat_app/features/auth/presentation/pages/mobile_number_screen.dart';
import 'package:ciro_chat_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:ciro_chat_app/features/auth/presentation/widgets/primary_button.dart';

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
          child: const MobileNumberScreen(),
        ),
      ),
    );
  }

  testWidgets('should show loading indicator when state is AuthLoading', (tester) async {
    // arrange
    when(() => mockAuthCubit.state).thenReturn(const AuthLoading());
    when(() => mockAuthCubit.stream).thenAnswer((_) => Stream.value(const AuthLoading()));

    // act
    await tester.pumpWidget(createWidgetUnderTest());

    // assert
    final primaryButton = find.byType(PrimaryButton);
    expect(primaryButton, findsOneWidget);
    
    // Check if the CircularProgressIndicator is present inside PrimaryButton
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
