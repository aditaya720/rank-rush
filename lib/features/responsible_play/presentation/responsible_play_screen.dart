import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../wallet/domain/user_profile.dart';
import '../../wallet/presentation/wallet_providers.dart';
import 'responsible_providers.dart';

/// Player-facing responsible-play controls: a session timer with break nudges,
/// a personal daily wager reminder, and self-exclusion.
///
/// These are on-device guardrails and reminders. The server independently
/// enforces its own hard limits and honours self-exclusion regardless of what
/// is shown here — the client can never grant itself more play than the server
/// allows.
class ResponsiblePlayScreen extends ConsumerStatefulWidget {
  const ResponsiblePlayScreen({super.key});

  @override
  ConsumerState<ResponsiblePlayScreen> createState() =>
      _ResponsiblePlayScreenState();
}

class _ResponsiblePlayScreenState extends ConsumerState<ResponsiblePlayScreen> {
  /// How many break-reminder intervals the player has already dismissed, so we
  /// re-surface the nudge once each new interval elapses rather than nagging
  /// every second.
  int _dismissedIntervalCount = 0;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(responsiblePrefsProvider);
    final elapsed =
        ref.watch(sessionElapsedProvider).valueOrNull ?? Duration.zero;
    final profile = ref.watch(userProfileProvider).valueOrNull;

    final intervalMinutes = prefs.breakReminderMinutes;
    final intervalsPassed =
        intervalMinutes <= 0 ? 0 : elapsed.inMinutes ~/ intervalMinutes;
    final showBreakNudge =
        intervalsPassed >= 1 && intervalsPassed > _dismissedIntervalCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Responsible play')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (showBreakNudge) ...[
              _BreakNudge(
                elapsed: elapsed,
                onDismiss: () =>
                    setState(() => _dismissedIntervalCount = intervalsPassed),
              ),
              const SizedBox(height: 16),
            ],
            _SessionCard(elapsed: elapsed, prefs: prefs),
            const SizedBox(height: 16),
            const _DailyLimitCard(),
            const SizedBox(height: 16),
            _SelfExclusionCard(profile: profile),
            const SizedBox(height: 16),
            const _StayInControlCard(),
            const SizedBox(height: 16),
            const VirtualCoinNotice(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _BreakNudge extends StatelessWidget {
  const _BreakNudge({required this.elapsed, required this.onDismiss});

  final Duration elapsed;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.self_improvement, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time for a break?',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  "You've been playing for ${_spokenDuration(elapsed)}. "
                  'Stepping away for a bit is a good way to keep it fun.',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.elapsed, required this.prefs});

  final Duration elapsed;
  final ResponsiblePrefs prefs;

  static const List<int> _options = [30, 60, 90];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCard(
      title: 'This session',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.feltBright.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.timer_outlined,
                    color: AppColors.feltBright),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _clockHhMmSs(elapsed),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Text(
                      'Time played since you opened the app',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Remind me to take a break every',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          ),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: [
              for (final m in _options)
                ButtonSegment<int>(value: m, label: Text('$m min')),
            ],
            selected: {
              _options.contains(prefs.breakReminderMinutes)
                  ? prefs.breakReminderMinutes
                  : 60,
            },
            showSelectedIcon: false,
            onSelectionChanged: (selection) => ref
                .read(responsiblePrefsProvider.notifier)
                .setBreakReminder(selection.first),
          ),
        ],
      ),
    );
  }
}

class _DailyLimitCard extends ConsumerWidget {
  const _DailyLimitCard();

  static const List<int> _presets = [0, 1000, 5000, 10000, 25000, 50000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(responsiblePrefsProvider);
    final wagered = ref.watch(todaysWageredProvider);
    final limit = prefs.dailyCoinLimit;
    final hasLimit = limit > 0;
    final progress =
        hasLimit ? (wagered / limit).clamp(0.0, 1.0).toDouble() : 0.0;
    final reached = hasLimit && wagered >= limit;

    return SectionCard(
      title: 'Daily play reminder',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Set a personal daily amount to stay aware of how much you play. '
            "It's a reminder for you — it doesn't change the coins the server "
            'gives you.',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          if (hasLimit) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${Formatters.coins(wagered)} wagered today',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                Text(
                  'of ${Formatters.coins(limit)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: AppColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation<Color>(
                  reached ? AppColors.loss : AppColors.feltBright,
                ),
              ),
            ),
            if (reached) ...[
              const SizedBox(height: 10),
              Row(
                children: const [
                  Icon(Icons.info_outline, size: 16, color: AppColors.loss),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "You've reached the daily amount you set for yourself. "
                      'Consider taking a break.',
                      style:
                          TextStyle(color: AppColors.loss, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: const [
                Icon(Icons.flag_outlined,
                    size: 16, color: AppColors.textMuted),
                SizedBox(width: 6),
                Text(
                  'No daily reminder set',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in _presets)
                _LimitChip(
                  label: preset == 0 ? 'Off' : Formatters.coins(preset),
                  selected: limit == preset,
                  onTap: () => ref
                      .read(responsiblePrefsProvider.notifier)
                      .setDailyLimit(preset),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.feltBright.withValues(alpha: 0.18)
          : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.feltBright
                  : const Color(0x22FFFFFF),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: selected ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelfExclusionCard extends ConsumerWidget {
  const _SelfExclusionCard({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(walletActionsProvider).isLoading;
    final excluded = profile?.isSelfExcluded ?? false;

    return SectionCard(
      title: 'Take a break from playing',
      child: excluded
          ? _ActiveExclusion(until: profile!.selfExcludedUntil!)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Self-exclusion locks you out of placing any bets for the '
                  'period you choose. It cannot be lifted early, so pick a '
                  'length you are comfortable with.',
                  style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12.5,
                      height: 1.35),
                ),
                const SizedBox(height: 14),
                _ExclusionButton(
                  label: 'Pause for 24 hours',
                  hours: 24,
                  enabled: !busy,
                  onConfirm: (h) => _confirmAndApply(context, ref, h,
                      '24 hours'),
                ),
                const SizedBox(height: 10),
                _ExclusionButton(
                  label: 'Pause for 7 days',
                  hours: 24 * 7,
                  enabled: !busy,
                  onConfirm: (h) =>
                      _confirmAndApply(context, ref, h, '7 days'),
                ),
                const SizedBox(height: 10),
                _ExclusionButton(
                  label: 'Pause for 30 days',
                  hours: 24 * 30,
                  enabled: !busy,
                  onConfirm: (h) =>
                      _confirmAndApply(context, ref, h, '30 days'),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmAndApply(
    BuildContext context,
    WidgetRef ref,
    int hours,
    String label,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm self-exclusion'),
        content: Text(
          'You will not be able to place any bets for $label. This starts '
          'immediately and cannot be undone until the period ends.\n\n'
          'You can still sign in and view your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Pause for $label'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final until =
          await ref.read(walletActionsProvider.notifier).selfExclude(hours: hours);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
                'Self-exclusion active until ${_formatUntil(until)}.'),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mapError(e).message)));
    }
  }
}

class _ExclusionButton extends StatelessWidget {
  const _ExclusionButton({
    required this.label,
    required this.hours,
    required this.enabled,
    required this.onConfirm,
  });

  final String label;
  final int hours;
  final bool enabled;
  final ValueChanged<int> onConfirm;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? () => onConfirm(hours) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.loss,
        side: BorderSide(color: AppColors.loss.withValues(alpha: 0.6)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ActiveExclusion extends StatelessWidget {
  const _ActiveExclusion({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.loss.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.loss.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_clock, color: AppColors.loss),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Self-exclusion is active',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Betting is paused until ${_formatUntil(until)}. '
                  'Take this time for yourself — the game will be here when '
                  "you're ready.",
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StayInControlCard extends StatelessWidget {
  const _StayInControlCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Stay in control',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Guideline(
            icon: Icons.emoji_emotions_outlined,
            text: 'Rank Rush is a game for entertainment, not a way to make '
                'money. The coins have no cash value.',
          ),
          _Guideline(
            icon: Icons.schedule,
            text: 'Play for fun and set your own time and coin reminders. '
                'Take regular breaks.',
          ),
          _Guideline(
            icon: Icons.cake_outlined,
            text: 'This game is intended for players aged 18 and over.',
          ),
          _Guideline(
            icon: Icons.favorite_border,
            text: 'If betting-style games ever stop feeling fun, or you play '
                'to escape stress, consider taking a break or talking to '
                'someone you trust.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _Guideline extends StatelessWidget {
  const _Guideline({
    required this.icon,
    required this.text,
    this.last = false,
  });

  final IconData icon;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.feltBright),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "1h 04m 09s" style clock for the session timer.
String _clockHhMmSs(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '${h}h ${m}m ${s}s';
  return '${m}m ${s}s';
}

/// Human phrasing for the break nudge ("about 1 hour", "45 minutes").
String _spokenDuration(Duration d) {
  final totalMinutes = d.inMinutes;
  if (totalMinutes < 60) return '$totalMinutes minutes';
  final hours = d.inHours;
  final minutes = totalMinutes.remainder(60);
  final hourWord = hours == 1 ? 'hour' : 'hours';
  if (minutes == 0) return '$hours $hourWord';
  return '$hours $hourWord ${minutes}m';
}

String _formatUntil(DateTime dt) =>
    DateFormat('EEE d MMM, h:mm a').format(dt.toLocal());
