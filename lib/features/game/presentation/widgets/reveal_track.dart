import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/widgets/playing_card_widget.dart';
import '../../domain/game_round.dart';

/// Renders the alternating reveal as two lanes — LEFT (even indices) on top,
/// RIGHT (odd indices) below — with one column per "turn". Cards flip face-up as
/// [visibleCount] advances (driven purely by the server's `revealStartedAt` +
/// `revealIntervalMs`), and the winning card gets a coloured glow once shown.
class RevealTrack extends StatelessWidget {
  const RevealTrack({
    super.key,
    required this.round,
    required this.visibleCount,
  });

  final GameRound round;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final steps = round.revealSequence;
    if (steps.isEmpty) {
      return const _EmptyTrack();
    }

    final columns = (steps.length + 1) ~/ 2;
    const cardWidth = 52.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LaneLabel(side: BetSide.left, isWinner: round.winner == BetSide.left),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var t = 0; t < columns; t++)
                    _slotAt(2 * t, cardWidth),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var t = 0; t < columns; t++)
                    _slotAt(2 * t + 1, cardWidth),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _LaneLabel(side: BetSide.right, isWinner: round.winner == BetSide.right),
      ],
    );
  }

  Widget _slotAt(int index, double width) {
    final steps = round.revealSequence;
    if (index >= steps.length) {
      // Pad the shorter lane so the columns stay aligned.
      return SizedBox(width: width + 8);
    }
    final step = steps[index];
    final revealed = index < visibleCount;
    final isWinning = round.winningIndex == index && revealed;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: revealed
          ? PlayingCardWidget(
              numericRank: step.card.numericRank,
              suit: step.card.suit,
              width: width,
              highlight: isWinning ? AppColors.win : null,
              dimmed: round.winningIndex != null &&
                  !isWinning &&
                  round.isFinished,
            )
          : PlayingCardWidget(
              numericRank: step.card.numericRank,
              suit: step.card.suit,
              width: width,
              faceUp: false,
            ),
    );
  }
}

class _LaneLabel extends StatelessWidget {
  const _LaneLabel({required this.side, required this.isWinner});

  final BetSide side;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final color = side == BetSide.left ? AppColors.left : AppColors.right;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          side.label,
          style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
        ),
        if (isWinner) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.win.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'WINNER',
              style: TextStyle(
                color: AppColors.win,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EmptyTrack extends StatelessWidget {
  const _EmptyTrack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: const Text(
        'Cards will be revealed here',
        style: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
