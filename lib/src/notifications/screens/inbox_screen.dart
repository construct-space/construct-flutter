// Notifications inbox — full screen, opened from Home's bell icon.
// Pulls inbox + unread count from Riverpod and supports refresh,
// mark-all-read, and per-row tap-to-mark-read.
//
// While this screen is mounted, an SSE connection to delivery-api's
// /api/notifications/stream is held open: incoming events invalidate
// inbox + unread providers so the list updates live. The connection
// is torn down in dispose() — Home and other screens do not pay for
// it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';
import '../models.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  void Function()? _stopStream;

  @override
  void initState() {
    super.initState();
    // Defer to first frame so the Riverpod container is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _stopStream = ref.read(notificationStreamClientProvider).listen(
        onNotification: (_) {
          // Cheapest path: invalidate the inbox provider so the row
          // re-fetch picks up the new item with whatever read state
          // the server has. Avoids the duplicate-event-vs-list race.
          if (!mounted) return;
          ref
            ..invalidate(inboxProvider)
            ..invalidate(unreadCountProvider);
        },
        onUnreadCount: (_) {
          if (!mounted) return;
          ref.invalidate(unreadCountProvider);
        },
        onError: (e) {
          // SSE auto-reconnects with backoff; just log so transient
          // blips don't surface as banner errors.
          debugPrint('[sse] $e');
        },
      );
    });
  }

  @override
  void dispose() {
    _stopStream?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final client = ref.watch(notificationsClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications${unread > 0 ? '  •  $unread' : ''}'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await client.markAllRead();
                ref
                  ..invalidate(inboxProvider)
                  ..invalidate(unreadCountProvider);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(inboxProvider)
            ..invalidate(unreadCountProvider);
          await ref.read(inboxProvider.future);
        },
        child: inbox.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
          ]),
          data: (items) {
            if (items.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text("You're all caught up.")),
              ]);
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = items[i];
                return _Row(
                  notification: n,
                  onTap: () async {
                    if (n.isUnread) await client.markRead(n.id);
                    ref
                      ..invalidate(inboxProvider)
                      ..invalidate(unreadCountProvider);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: notification.isUnread
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.notifications_outlined,
          size: 18,
          color: notification.isUnread ? Colors.white : null,
        ),
      ),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: notification.isUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: notification.body.isEmpty
          ? null
          : Text(notification.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
