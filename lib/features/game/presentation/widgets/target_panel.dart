import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/playing_card_widget.dart';
import '../../domain/game_round.dart';

/// Shows the round's target card and the rank both sides are racing to match.
///
/// The target card's *rank* is public during betting (it's what you're betting
/// on) — but the order of the remaining 51 cards stays hidden behind the
/// published seed hash until the round settles, so no one can know which side
/// wins in advance.
class TargetPanel extends StatelessWidget {
  const TargetPanel({super.key, required this.round});

  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final target = round.targetCard;
    final hasTarget = target != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.felt.withValues(alpha: 0.55),
            AppColors.ink.withValues(alpha: 0.2),
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            'TARGET RANK',
            style: TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 14),
          if (hasTarget)
            PlayingCardWidget(
              numericRank: target.numericRank,
              suit: target.suit,
              width: 92,
              highlight: AppColors.gold,
            )
          else
            const CardSlot(width: 92, label: '…'),
          const SizedBox(height: 14),
          Text(
            hasTarget
                ? 'First side to reveal a ${Formatters.rankWord(target.numericRank)} wins'
                : 'Preparing the next round…',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pays ${Formatters.multiplier(round.payoutMultiplier)} on a win',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
