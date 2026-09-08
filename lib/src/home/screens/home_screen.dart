// Home — the post-login landing. AppBar carries the bell (with unread
// badge) and the sign-out action. Body shows a personalized greeting
// while we figure out what real content lives here.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assistant/screens/ask_screen.dart';
import '../../notifications/screens/inbox_screen.dart';
import '../../operator_status/widgets.dart';
import '../../providers.dart';
import '../../theme/construct_theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(scopeProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CONSTRUCT',
          style: theme.textTheme.titleMedium?.copyWith(
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          const OperatorStatusDot(),
          _BellAction(
            unread: unread,
            onPressed: () {
              // Refresh inbox state when entering the screen so the user
              // doesn't see a stale list.
              ref
                ..invalidate(inboxProvider)
                ..invalidate(unreadCountProvider);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InboxScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: scope.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Failed to load profile: $e', textAlign: TextAlign.center),
            data: (s) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: ConstructColors.surfaceTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.waving_hand,
                    size: 30,
                    color: ConstructColors.accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Welcome, ${s.user.firstNameOrUsername}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  s.user.email,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (s.org != null) ...[
                  const SizedBox(height: 12),
                  Chip(
                    avatar: const Icon(Icons.business, size: 16),
                    label: Text(s.org!.name ?? s.org!.slug),
                  ),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Ask the Assistant'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AskScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BellAction extends StatelessWidget {
  const _BellAction({required this.unread, required this.onPressed});

  final int unread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined),
          onPressed: onPressed,
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unread > 99 ? '99+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}
