// Tiny status pill for the AppBar — green dot when the user's
// operator is connected, red when not. Tap to open a bottom sheet
// with platform-specific "keep your machine awake" instructions so
// the user doesn't sit there waiting on a sleeping Mac.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/construct_theme.dart';

class OperatorStatusDot extends ConsumerWidget {
  const OperatorStatusDot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(operatorStatusProvider);
    final online = status.value?.online ?? false;
    final color = online ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final label = online ? 'Operator online' : 'Operator offline';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: online ? null : () => _showOfflineHelp(context),
          radius: 22,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulseDot(color: color, pulsing: !online),
                const SizedBox(width: 6),
                Text(
                  online ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: ConstructColors.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    letterSpacing: 0.4,
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

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color, required this.pulsing});
  final Color color;
  final bool pulsing;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.pulsing) _ctl.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseDot old) {
    super.didUpdateWidget(old);
    if (widget.pulsing && !_ctl.isAnimating) _ctl.repeat();
    if (!widget.pulsing && _ctl.isAnimating) _ctl.stop();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) {
        final pulse = (1 - (_ctl.value - 0.5).abs() * 2).clamp(0.0, 1.0);
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: widget.pulsing
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6 * pulse),
                      blurRadius: 6 + 4 * pulse,
                      spreadRadius: 1 + pulse,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

void _showOfflineHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => const _OfflineHelpSheet(),
  );
}

class _OfflineHelpSheet extends StatelessWidget {
  const _OfflineHelpSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bedtime_outlined,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operator offline',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Your desktop is unreachable.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'What\'s probably happening',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Construct is running on your desktop, but your machine is asleep or offline. Wake it and the dot turns green within a few seconds — no need to relaunch the app.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'Keep it awake while you\'re mobile',
              style: theme.textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            const _PlatformBlock(
              icon: Icons.laptop_mac,
              title: 'macOS',
              steps: [
                'System Settings → Lock Screen → "Start Screen Saver when inactive: Never" + "Turn display off…: Never" while on power.',
                'System Settings → Energy → tick "Prevent automatic sleeping when the display is off" and "Wake for network access".',
                'Quick override: open Terminal and run `caffeinate -i` — keeps the Mac awake until you Ctrl-C it.',
              ],
            ),
            _PlatformBlock(
              icon: Icons.laptop_windows,
              title: 'Windows',
              steps: const [
                'Settings → System → Power & battery → Screen and sleep → "When plugged in, put my device to sleep after: Never".',
                'Or pin Construct to startup so it auto-launches if Windows is restarted overnight.',
              ],
            ),
            _PlatformBlock(
              icon: Icons.laptop_chromebook,
              title: 'Linux',
              steps: const [
                'GNOME: Settings → Power → Automatic Suspend: Off (or only when on battery).',
                'Or run `systemd-inhibit --what=idle:sleep sleep infinity` in a terminal you keep open.',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatformBlock extends StatelessWidget {
  const _PlatformBlock({
    required this.icon,
    required this.title,
    required this.steps,
  });

  final IconData icon;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ConstructColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ConstructColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ConstructColors.foreground),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${i + 1}. ',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: ConstructColors.muted,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ConstructColors.foreground,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
