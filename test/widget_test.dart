import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likeehit_flutter/login_screen.dart';

void main() {
  testWidgets('Login screen renders unauthenticated entry point', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome to LikeeHit'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    expect(find.byIcon(Icons.video_library), findsOneWidget);
  });
}
