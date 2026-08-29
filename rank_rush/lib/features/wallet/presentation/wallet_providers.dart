import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/firebase_providers.dart';
import '../data/wallet_repository.dart';
import '../domain/coin_transaction.dart';
import '../domain/user_profile.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    firestore: ref.watch(firestoreProvider),
    functions: ref.watch(functionsProvider),
  );
});

/// Live profile for the signed-in user (null when signed out / not yet loaded).
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(walletRepositoryProvider).watchProfile(uid);
});

/// Convenience: just the coin balance (0 until loaded).
final coinBalanceProvider = Provider<int>((ref) {
  return ref.watch(userProfileProvider).valueOrNull?.virtualCoinBalance ?? 0;
});

final transactionsProvider = StreamProvider<List<CoinTransaction>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(walletRepositoryProvider).watchTransactions(uid);
});

/// Actions that mutate the wallet via Cloud Functions (claim bonus, self-exclude).
class WalletActions extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<DailyBonusResult> claimDailyBonus() async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(walletRepositoryProvider).claimDailyBonus();
      state = const AsyncData(null);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<DateTime> selfExclude({required int hours}) async {
    state = const AsyncLoading();
    try {
      final until = await ref.read(walletRepositoryProvider).selfExclude(hours: hours);
      state = const AsyncData(null);
      return until;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final walletActionsProvider =
    AsyncNotifierProvider<WalletActions, void>(WalletActions.new);
