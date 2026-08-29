import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/bet.dart';
import '../../domain/game_round.dart';

/// The outcome card shown once a round is finished: win / loss / no-bet, plus a
/// shortcut to independently verify the result.
class RoundResultBanner extends StatelessWidget {
  const RoundResultBanner({
    super.key,
    required this.round,
    required this.myBet,
    required this.onVerify,
  });

  final GameRound round;
  final Bet? myBet;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final winner = round.winner;
    final bet = myBet;

    final Color color;
    final IconData icon;
    final String title;
    final String subtitle;

    if (bet == null) {
      color = AppColors.textMuted;
      icon = Icons.remove_circle_outline;
      title = 'Round over';
      subtitle = winner == null
          ? 'This round was cancelled.'
          : '${winner.label} won this round. You sat this one out.';
    } else if (round.isCancelled) {
      color = AppColors.textMuted;
      icon = Icons.refresh;
      title = 'Round cancelled';
      subtitle = 'Your ${Formatters.coins(bet.stake)} coin stake was refunded.';
    } else {
      final won = winner != null && bet.side == winner;
      if (won) {
        final payout = bet.isSettled
            ? bet.payout
            : (bet.stake * round.payoutMultiplier).floor();
        final profit = bet.isSettled ? bet.netProfit : payout - bet.stake;
        color = AppColors.win;
        icon = Icons.emoji_events;
        title = 'You won!';
        subtitle =
            '+${Formatters.coins(profit)} coins (paid ${Formatters.coins(payout)})';
      } else {
        color = AppColors.loss;
        icon = Icons.sentiment_dissatisfied;
        title = 'You lost';
        subtitle =
            '-${Formatters.coins(bet.stake)} coins · ${winner?.label ?? '—'} took it';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onVerify,
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: const Text('Verify this round'),
          ),
        ],
      ),
    );
  }
}
