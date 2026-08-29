import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../shared/providers/firebase_providers.dart';
import '../data/game_repository.dart';
import '../domain/bet.dart';
import '../domain/game_round.dart';

final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return GameRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(functionsProvider),
  );
});

/// The id of the current round for the default table.
final currentRoundIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(gameRepositoryProvider).watchCurrentRoundId(AppConfig.gameId);
});

/// The live current round document.
final currentRoundProvider = StreamProvider<GameRound?>((ref) {
  final roundId = ref.watch(currentRoundIdProvider).valueOrNull;
  if (roundId == null) return Stream.value(null);
  return ref.watch(gameRepositoryProvider).watchRound(AppConfig.gameId, roundId);
});

/// The current user's bet on the live round, if any.
final myBetProvider = StreamProvider<Bet?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final roundId = ref.watch(currentRoundIdProvider).valueOrNull;
  if (uid == null || roundId == null) return Stream.value(null);
  return ref
      .watch(gameRepositoryProvider)
      .watchMyBet(AppConfig.gameId, roundId, uid);
});

/// Emits the current time a few times a second to drive countdowns and the
/// reveal animation without per-widget timers.
final tickerProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  final timer = Timer.periodic(
    const Duration(milliseconds: 200),
    (_) => controller.add(DateTime.now()),
  );
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Keeps the shared game advancing while a client is watching. It periodically
/// pings `syncRound` (create first round / settle expired / open next). The
/// scheduled backstop on the server does the same if nobody is online.
final gameDriverProvider = Provider.autoDispose<void>((ref) {
  final repo = ref.watch(gameRepositoryProvider);
  const gameId = AppConfig.gameId;
  unawaited(repo.syncRound(gameId));
  final timer = Timer.periodic(
    const Duration(seconds: 3),
    (_) => unawaited(repo.syncRound(gameId)),
  );
  ref.onDispose(timer.cancel);
});

/// The user's pending bet-slip selection before submission.
class BetSlip {
  const BetSlip({this.side, required this.stake});
  final BetSide? side;
  final int stake;

  BetSlip copyWith({BetSide? side, int? stake, bool clearSide = false}) => BetSlip(
        side: clearSide ? null : (side ?? this.side),
        stake: stake ?? this.stake,
      );
}

class BetSlipNotifier extends Notifier<BetSlip> {
  @override
  BetSlip build() => const BetSlip(stake: 100);

  void selectSide(BetSide side) => state = state.copyWith(side: side);
  void setStake(int stake) => state = state.copyWith(stake: stake < 0 ? 0 : stake);
  void addStake(int delta) => setStake(state.stake + delta);
  void reset() => state = const BetSlip(stake: 100);
}

final betSlipProvider = NotifierProvider<BetSlipNotifier, BetSlip>(BetSlipNotifier.new);

/// Handles bet submission with loading/error state. Uses a deterministic
/// `betId` (`uid_roundId`) so a retry is naturally idempotent on the server.
class PlaceBetController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<PlaceBetResult> submit({
    required String roundId,
    required BetSide side,
    required int stake,
  }) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      throw StateError('Not signed in.');
    }
    state = const AsyncLoading();
    try {
      final result = await ref.read(gameRepositoryProvider).placeBet(
            gameId: AppConfig.gameId,
            roundId: roundId,
            betId: '${uid}_$roundId',
            side: side,
            stake: stake,
          );
      state = const AsyncData(null);
      ref.read(betSlipProvider.notifier).reset();
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final placeBetControllerProvider =
    AsyncNotifierProvider<PlaceBetController, void>(PlaceBetController.new);
