import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../domain/coin_transaction.dart';
import 'wallet_providers.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final txAsync = ref.watch(transactionsProvider);
    final claiming = ref.watch(walletActionsProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _BalanceHero(balance: profile?.virtualCoinBalance ?? 0),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: claiming ? null : () => _claim(context, ref),
              icon: claiming
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.card_giftcard),
              label: const Text('Claim daily bonus'),
            ),
            const SizedBox(height: 20),
            SectionCard(
              title: 'Your stats',
              child: Row(
                children: [
                  _StatCell(label: 'Games', value: '${profile?.totalGames ?? 0}'),
                  _StatCell(label: 'Wins', value: '${profile?.totalWins ?? 0}'),
                  _StatCell(label: 'Losses', value: '${profile?.totalLosses ?? 0}'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Recent activity',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            txAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: LoadingView(),
              ),
              error: (e, _) => ErrorView(message: mapError(e).message),
              data: (txs) => txs.isEmpty
                  ? const _EmptyLedger()
                  : Column(
                      children: [
                        for (final tx in txs) _TxTile(tx: tx),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            const VirtualCoinNotice(),
          ],
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result =
          await ref.read(walletActionsProvider.notifier).claimDailyBonus();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '+${Formatters.coins(result.amount)} coins claimed! '
              'Day ${result.streak} streak.',
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

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balance});
  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.22),
            AppColors.surfaceHigh,
          ],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Text('Virtual coin balance',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: AppColors.gold, size: 30),
              const SizedBox(width: 10),
              Text(
                Formatters.coins(balance),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Play money — not redeemable for cash',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});
  final CoinTransaction tx;

  @override
  Widget build(BuildContext context) {
    final positive = tx.amount >= 0;
    final color = positive ? AppColors.win : AppColors.loss;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(tx.type), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.type.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (tx.timestamp != null)
                  Text(Formatters.relativeTime(tx.timestamp!),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.signedCoins(tx.amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              Text('bal ${Formatters.coins(tx.balanceAfter)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(CoinTxType type) {
    switch (type) {
      case CoinTxType.bet:
        return Icons.upload;
      case CoinTxType.win:
        return Icons.emoji_events;
      case CoinTxType.loss:
        return Icons.trending_down;
      case CoinTxType.bonus:
        return Icons.card_giftcard;
      case CoinTxType.refund:
        return Icons.undo;
      case CoinTxType.adminAdjustment:
        return Icons.tune;
      case CoinTxType.unknown:
        return Icons.receipt_long;
    }
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.receipt_long, color: AppColors.textMuted, size: 34),
          SizedBox(height: 10),
          Text('No transactions yet',
              style: TextStyle(color: AppColors.textMuted)),
          SizedBox(height: 2),
          Text('Place your first bet to get started.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
