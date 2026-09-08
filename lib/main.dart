// Construct mobile entry. The whole app is feature-foldered under
// lib/src/<feature>/ — main.dart only owns boot (Firebase, ProviderScope,
// MaterialApp) and the post-frame hook that kicks off push registration
// when the user is already signed in.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/auth/screens/auth_gate.dart';
import 'src/notifications/push.dart';
import 'src/providers.dart';
import 'src/theme/construct_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is optional during early bring-up — without
  // GoogleService-Info.plist (iOS) / google-services.json (Android) the
  // initializer throws. Catch so the app still boots and the UI renders;
  // PushService.init() also won't run, which is fine since there's no
  // FCM project to register against yet.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('[firebase] init skipped: $e');
  }
  runApp(const ProviderScope(child: ConstructApp()));
}

class ConstructApp extends ConsumerStatefulWidget {
  const ConstructApp({super.key});

  @override
  ConsumerState<ConstructApp> createState() => _ConstructAppState();
}

class _ConstructAppState extends ConsumerState<ConstructApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Wait until auth resolves at least once, then init push only if
      // the user is already signed in (token persisted from a previous
      // session). Sign-in *during* this run won't retro-init push;
      // we'll address that when the login flow grows a post-success hook.
      final token = await ref.read(authProvider.future);
      if (token == null || token.isEmpty) return;
      try {
        final push = PushService(ref.read(notificationsClientProvider));
        await push.init();
      } catch (e) {
        debugPrint('[push] init skipped: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Construct',
      theme: buildConstructTheme(),
      home: const AuthGate(),
    );
  }
}
