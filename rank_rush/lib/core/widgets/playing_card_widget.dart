import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../utils/formatters.dart';

/// A vector-drawn playing card. No bitmap assets are used anywhere in the app —
/// cards are rendered entirely from their rank + suit, which keeps the bundle
/// tiny and the rendering crisp at any size.
class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    required this.numericRank,
    required this.suit,
    this.width = 68,
    this.faceUp = true,
    this.highlight,
    this.dimmed = false,
  });

  final int numericRank;
  final String suit;
  final double width;
  final bool faceUp;

  /// Optional glow colour (e.g. the winning card).
  final Color? highlight;

  /// Render at reduced opacity (e.g. non-winning revealed cards).
  final bool dimmed;

  bool get _isRed => suit == 'hearts' || suit == 'diamonds';

  @override
  Widget build(BuildContext context) {
    final height = width * 1.4;
    final radius = width * 0.12;

    if (!faceUp) {
      return _CardBack(width: width, height: height, radius: radius);
    }

    final color = _isRed ? AppColors.cardRed : AppColors.cardBlack;
    final rank = Formatters.rankLabel(numericRank);
    final glyph = Formatters.suitGlyph(suit);

    final card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.cardFace,
        borderRadius: BorderRadius.circular(radius),
        border: highlight != null
            ? Border.all(color: highlight!, width: 3)
            : Border.all(color: const Color(0x22000000)),
        boxShadow: [
          if (highlight != null)
            BoxShadow(color: highlight!.withValues(alpha: 0.55), blurRadius: 16, spreadRadius: 1),
          const BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(width * 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rank,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: width * 0.30,
                height: 1,
              ),
            ),
            Text(glyph, style: TextStyle(color: color, fontSize: width * 0.22, height: 1)),
            Expanded(
              child: Center(
                child: Text(glyph, style: TextStyle(color: color, fontSize: width * 0.5)),
              ),
            ),
          ],
        ),
      ),
    );

    return Opacity(opacity: dimmed ? 0.45 : 1, child: card);
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.width, required this.height, required this.radius});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.feltBright, AppColors.felt],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
      ),
      child: Center(
        child: Icon(Icons.auto_awesome, color: AppColors.gold.withValues(alpha: 0.85), size: width * 0.4),
      ),
    );
  }
}

/// A compact placeholder shown where a card will be revealed.
class CardSlot extends StatelessWidget {
  const CardSlot({super.key, this.width = 68, this.label});

  final double width;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.4;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: const Color(0x33FFFFFF)),
        color: const Color(0x11FFFFFF),
      ),
      alignment: Alignment.center,
      child: label == null
          ? null
          : Text(label!, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
    );
  }
}
