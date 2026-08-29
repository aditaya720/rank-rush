import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../utils/formatters.dart';

/// A gold coin balance pill used in app bars and headers.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.balance, this.compact = false});

  final int balance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: AppColors.gold, size: 18),
          const SizedBox(width: 6),
          Text(
            Formatters.coins(balance),
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            const Text('coins', style: TextStyle(color: AppColors.goldDim, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// The always-present reminder that this game uses play money only. Required by
/// the responsible-play design — it appears on the game and wallet screens.
class VirtualCoinNotice extends StatelessWidget {
  const VirtualCoinNotice({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 8 : 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Virtual coins only — no real money, no purchases, no cash-outs. For entertainment.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: dense ? 11.5 : 12.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled surface container used throughout the app.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.trailing, this.padding});

  final String? title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Simple centered loading indicator.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Simple centered error state with an optional retry.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.loss, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
