import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/bet.dart';
import '../../domain/game_round.dart';
import '../game_providers.dart';

/// The betting form (side + stake + submit). Once the player has a bet on the
/// round it collapses into a read-only summary. All amounts are virtual coins;
/// the server re-validates every value, so this UI is purely for convenience.
class BettingPanel extends ConsumerWidget {
  const BettingPanel({
    super.key,
    required this.round,
    required this.myBet,
    required this.balance,
  });

  final GameRound round;
  final Bet? myBet;
  final int balance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (myBet != null) {
      return _PlacedSummary(round: round, bet: myBet!);
    }

    final slip = ref.watch(betSlipProvider);
    final placing = ref.watch(placeBetControllerProvider).isLoading;

    final step = round.minBet > 0 ? round.minBet : 50;
    final stakeValid = slip.stake >= round.minBet &&
        slip.stake <= round.maxBet &&
        slip.stake <= balance;
    final canPlace =
        slip.side != null && stakeValid && !placing && slip.stake > 0;

    final potential = (slip.stake * round.payoutMultiplier).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SideButton(
                side: BetSide.left,
                selected: slip.side == BetSide.left,
                players: round.leftPlayers,
                pool: round.leftStake,
                onTap: () =>
                    ref.read(betSlipProvider.notifier).selectSide(BetSide.left),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SideButton(
                side: BetSide.right,
                selected: slip.side == BetSide.right,
                players: round.rightPlayers,
                pool: round.rightStake,
                onTap: () => ref
                    .read(betSlipProvider.notifier)
                    .selectSide(BetSide.right),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Stake', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              'Min ${Formatters.coins(round.minBet)} · Max ${Formatters.coins(round.maxBet)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              onTap: () => ref.read(betSlipProvider.notifier).addStake(-step),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    Formatters.coins(slip.stake),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                  const Text('coins',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            _StepButton(
              icon: Icons.add,
              onTap: () => ref.read(betSlipProvider.notifier).addStake(step),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final preset in _presets())
              ActionChip(
                label: Text(Formatters.coins(preset)),
                onPressed: () =>
                    ref.read(betSlipProvider.notifier).setStake(preset),
              ),
            if (balance >= round.minBet)
              ActionChip(
                label: const Text('Max'),
                onPressed: () => ref.read(betSlipProvider.notifier).setStake(
                      balance < round.maxBet ? balance : round.maxBet,
                    ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!stakeValid)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              slip.stake > balance
                  ? 'Not enough coins for that stake.'
                  : 'Stake must be between ${Formatters.coins(round.minBet)} and ${Formatters.coins(round.maxBet)}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.loss, fontSize: 12.5),
            ),
          ),
        FilledButton(
          onPressed: canPlace
              ? () => _submit(context, ref, slip.side!, slip.stake)
              : null,
          child: placing
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : Text(
                  slip.side == null
                      ? 'Pick a side'
                      : 'Bet ${Formatters.coins(slip.stake)} on ${slip.side!.label} · win ${Formatters.coins(potential)}',
                ),
        ),
      ],
    );
  }

  List<int> _presets() {
    final candidates = <int>{round.minBet, 100, 500, 1000};
    return candidates
        .where((v) => v >= round.minBet && v <= round.maxBet && v <= balance)
        .toList()
      ..sort();
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    BetSide side,
    int stake,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(placeBetControllerProvider.notifier).submit(
            roundId: round.id,
            side: side,
            stake: stake,
          );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Bet placed on ${side.label} · balance ${Formatters.coins(result.newBalance)}',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mapError(e).message)));
    }
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.side,
    required this.selected,
    required this.players,
    required this.pool,
    required this.onTap,
  });

  final BetSide side;
  final bool selected;
  final int players;
  final int pool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = side == BetSide.left ? AppColors.left : AppColors.right;
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : const Color(0x22FFFFFF),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                side.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$players ${players == 1 ? 'player' : 'players'}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              Text(
                '${Formatters.coins(pool)} in',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceHigh,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

class _PlacedSummary extends StatelessWidget {
  const _PlacedSummary({required this.round, required this.bet});
  final GameRound round;
  final Bet bet;

  @override
  Widget build(BuildContext context) {
    final color = bet.side == BetSide.left ? AppColors.left : AppColors.right;
    final potential = (bet.stake * round.payoutMultiplier).floor();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "You're in on ${bet.side.label}",
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Staked ${Formatters.coins(bet.stake)} · win ${Formatters.coins(potential)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
