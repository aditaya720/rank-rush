import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// A depleting progress bar + seconds readout for the betting window.
///
/// The betting window length isn't sent explicitly, so we treat the largest
/// remaining time observed for the current round as the full window. This gives
/// a smooth, correct-looking countdown whether the player joined at the start of
/// betting or midway through.
class CountdownBar extends StatefulWidget {
  const CountdownBar({
    super.key,
    required this.roundId,
    required this.millisLeft,
  });

  final String roundId;
  final int millisLeft;

  @override
  State<CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<CountdownBar> {
  late String _trackedRound;
  late int _maxMillis;

  @override
  void initState() {
    super.initState();
    _trackedRound = widget.roundId;
    _maxMillis = widget.millisLeft > 0 ? widget.millisLeft : 1;
  }

  @override
  void didUpdateWidget(CountdownBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.roundId != _trackedRound) {
      _trackedRound = widget.roundId;
      _maxMillis = widget.millisLeft > 0 ? widget.millisLeft : 1;
    } else if (widget.millisLeft > _maxMillis) {
      _maxMillis = widget.millisLeft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fraction =
        _maxMillis <= 0 ? 0.0 : (widget.millisLeft / _maxMillis).clamp(0.0, 1.0);
    final secondsLeft = (widget.millisLeft / 1000).ceil();
    final urgent = widget.millisLeft <= 3000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Betting closes in',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
            Text(
              '${secondsLeft}s',
              style: TextStyle(
                color: urgent ? AppColors.loss : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation<Color>(
              urgent ? AppColors.loss : AppColors.feltBright,
            ),
          ),
        ),
      ],
    );
  }
}
