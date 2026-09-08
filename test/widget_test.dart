// Smoke test — boot the app shell wrapped in ProviderScope. With no
// stored token the auth gate should land on the sign-in screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:construct/main.dart';

void main() {
  testWidgets('boots into sign-in when unauthenticated', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ConstructApp()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sign in'), findsOneWidget);
  });
}
