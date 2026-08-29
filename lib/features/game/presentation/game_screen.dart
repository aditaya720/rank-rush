import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../wallet/presentation/wallet_providers.dart';
import '../domain/bet.dart';
import '../domain/game_round.dart';
import 'game_providers.dart';
import 'widgets/betting_panel.dart';
import 'widgets/countdown_bar.dart';
import 'widgets/reveal_track.dart';
import 'widgets/round_result_banner.dart';
import 'widgets/target_panel.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the shared game advancing while this screen is open.
    ref.watch(gameDriverProvider);

    final roundAsync = ref.watch(currentRoundProvider);
    final balance = ref.watch(coinBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rank Rush Table',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: CoinBadge(balance: balance, compact: true)),
          ),
        ],
      ),
      body: SafeArea(
        child: roundAsync.when(
          loading: () => const LoadingView(message: 'Joining the table…'),
          error: (e, _) => ErrorView(
            message: 'Could not load the table.\n$e',
            onRetry: () => ref.invalidate(currentRoundIdProvider),
          ),
          data: (round) {
            if (round == null ||
                round.status == GameStatus.waiting) {
              return const _PreparingView();
            }
            return _RoundView(round: round);
          },
        ),
      ),
    );
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(tickerProvider).valueOrNull ?? DateTime.now();
    final myBet = ref.watch(myBetProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final balance = ref.watch(coinBalanceProvider);

    final selfExcluded = profile?.isSelfExcluded ?? false;
    final millisLeft = round.millisLeftToBet(now);
    final canBetNow = round.isBetting && millisLeft > 0 && !selfExcluded;
    final visibleReveal = round.visibleRevealCount(now);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TargetPanel(round: round),
        const SizedBox(height: 20),
        if (round.isBetting) ...[
          if (canBetNow)
            CountdownBar(roundId: round.id, millisLeft: millisLeft)
          else if (selfExcluded)
            const _SelfExcludedNotice()
          else
            const _StatusPill(
              icon: Icons.lock_clock,
              text: 'Betting is closing…',
            ),
          const SizedBox(height: 16),
          if (!selfExcluded)
            BettingPanel(round: round, myBet: myBet, balance: balance),
        ] else if (round.status == GameStatus.locked) ...[
          const _StatusPill(
            icon: Icons.lock_outline,
            text: 'Betting closed — dealing the reveal…',
          ),
          if (myBet != null) ...[
            const SizedBox(height: 14),
            _MyBetChip(bet: myBet),
          ],
        ] else if (round.isRevealing) ...[
          _StatusPill(
            icon: Icons.style,
            text: 'Revealing… ${round.targetCard != null ? 'find a ${Formatters.rankWord(round.targetNumericRank)}' : ''}',
          ),
          const SizedBox(height: 16),
          RevealTrack(round: round, visibleCount: visibleReveal),
          if (myBet != null) ...[
            const SizedBox(height: 14),
            _MyBetChip(bet: myBet),
          ],
        ] else if (round.isFinished || round.isCancelled) ...[
          RevealTrack(round: round, visibleCount: round.revealSequence.length),
          const SizedBox(height: 18),
          RoundResultBanner(
            round: round,
            myBet: myBet,
            onVerify: () => context.push(Routes.fairness, extra: round),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Next round starts automatically…',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _FairnessStrip(round: round),
        const SizedBox(height: 16),
        const VirtualCoinNotice(dense: true),
      ],
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Shuffling a fresh deck…',
              style: TextStyle(color: AppColors.textMuted)),
          SizedBox(height: 4),
          Text('The next round will open for betting shortly.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}

class _SelfExcludedNotice extends StatelessWidget {
  const _SelfExcludedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.loss.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.loss.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.pause_circle_outline, color: AppColors.loss),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are on a self-exclusion break, so betting is paused. You can '
              'still watch rounds. Manage this in Responsible play.',
              style: TextStyle(fontSize: 12.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyBetChip extends StatelessWidget {
  const _MyBetChip({required this.bet});
  final Bet bet;

  @override
  Widget build(BuildContext context) {
    final color = bet.side == BetSide.left ? AppColors.left : AppColors.right;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.person_pin_circle_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          'Your bet: ${bet.side.label} · ${Formatters.coins(bet.stake)} coins',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }
}

/// A small always-present reminder of the published seed commitment, so players
/// can see the round was committed before any card was dealt.
class _FairnessStrip extends StatelessWidget {
  const _FairnessStrip({required this.round});
  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final hash = round.serverSeedHash;
    final shortHash = hash.length > 16 ? '${hash.substring(0, 16)}…' : hash;
    return Row(
      children: [
        const Icon(Icons.lock, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Committed seed hash: $shortHash',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
