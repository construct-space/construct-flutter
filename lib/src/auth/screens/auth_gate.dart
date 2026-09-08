// Routes to Home when there's a stored cat_ token, sign-in screen
// otherwise. Mounted as MaterialApp.home so token state changes
// (sign-in / sign-out) cause an automatic re-route — no manual
// Navigator pushReplacement plumbing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/screens/home_screen.dart';
import '../../providers.dart';
import 'sign_in_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
      data: (token) => (token == null || token.isEmpty)
          ? const SignInScreen()
          : const HomeScreen(),
    );
  }
}
