import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wallet/domain/coin_transaction.dart';
import '../../wallet/presentation/wallet_providers.dart';

/// Captured the first time responsible-play state is observed in this app run —
/// used as the "session start" for the play-time reminder.
final _sessionStartProvider = Provider<DateTime>((ref) => DateTime.now());

/// Ticks once a second with how long the current session has been running, so
/// the UI can surface a gentle "time for a break" nudge.
final sessionElapsedProvider = StreamProvider<Duration>((ref) {
  final start = ref.watch(_sessionStartProvider);
  final controller = StreamController<Duration>();
  void emit() => controller.add(DateTime.now().difference(start));
  emit();
  final timer = Timer.periodic(const Duration(seconds: 1), (_) => emit());
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Personal, on-device responsible-play preferences. These are player-facing
/// guardrails and reminders; the server independently enforces its own hard
/// limits regardless of what's set here.
class ResponsiblePrefs {
  const ResponsiblePrefs({
    required this.breakReminderMinutes,
    required this.dailyCoinLimit,
  });

  /// Minutes of continuous play before a break is suggested.
  final int breakReminderMinutes;

  /// Personal daily wager reminder in virtual coins (0 = off).
  final int dailyCoinLimit;

  ResponsiblePrefs copyWith({int? breakReminderMinutes, int? dailyCoinLimit}) {
    return ResponsiblePrefs(
      breakReminderMinutes: breakReminderMinutes ?? this.breakReminderMinutes,
      dailyCoinLimit: dailyCoinLimit ?? this.dailyCoinLimit,
    );
  }
}

class ResponsiblePrefsNotifier extends Notifier<ResponsiblePrefs> {
  @override
  ResponsiblePrefs build() =>
      const ResponsiblePrefs(breakReminderMinutes: 60, dailyCoinLimit: 0);

  void setBreakReminder(int minutes) =>
      state = state.copyWith(breakReminderMinutes: minutes);

  void setDailyLimit(int coins) =>
      state = state.copyWith(dailyCoinLimit: coins < 0 ? 0 : coins);
}

final responsiblePrefsProvider =
    NotifierProvider<ResponsiblePrefsNotifier, ResponsiblePrefs>(
        ResponsiblePrefsNotifier.new);

/// Total virtual coins wagered today, derived from the visible ledger. Used to
/// show progress against the player's personal daily limit.
final todaysWageredProvider = Provider<int>((ref) {
  final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  var sum = 0;
  for (final tx in txs) {
    final ts = tx.timestamp;
    if (tx.type == CoinTxType.bet &&
        ts != null &&
        ts.year == now.year &&
        ts.month == now.month &&
        ts.day == now.day) {
      sum += tx.amount.abs();
    }
  }
  return sum;
});
