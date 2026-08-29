import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../authentication/presentation/auth_controller.dart';
import '../../wallet/presentation/wallet_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rank Rush', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: CoinBadge(balance: profile?.virtualCoinBalance ?? 0)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WelcomeCard(
              name: profile?.displayName ?? 'Player',
              games: profile?.totalGames ?? 0,
              wins: profile?.totalWins ?? 0,
              winRate: profile?.winRate ?? 0,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push(Routes.game),
              icon: const Icon(Icons.casino_rounded),
              label: const Text('Play now'),
            ),
            const SizedBox(height: 20),
            const Text('Menu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.gold,
              title: 'Wallet',
              subtitle: 'Balance, daily bonus & history',
              onTap: () => context.push(Routes.wallet),
            ),
            _MenuTile(
              icon: Icons.leaderboard_outlined,
              color: AppColors.left,
              title: 'Leaderboard',
              subtitle: 'Top players by coins & weekly wins',
              onTap: () => context.push(Routes.leaderboard),
            ),
            _MenuTile(
              icon: Icons.verified_user_outlined,
              color: AppColors.win,
              title: 'Provable fairness',
              subtitle: 'Verify any round yourself',
              onTap: () => context.push(Routes.fairness),
            ),
            _MenuTile(
              icon: Icons.health_and_safety_outlined,
              color: AppColors.right,
              title: 'Responsible play',
              subtitle: 'Limits, breaks & self-exclusion',
              onTap: () => context.push(Routes.responsible),
            ),
            const SizedBox(height: 20),
            const VirtualCoinNotice(),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.name,
    required this.games,
    required this.wins,
    required this.winRate,
  });

  final String name;
  final int games;
  final int wins;
  final double winRate;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back,', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'Games', value: '$games'),
              _Stat(label: 'Wins', value: '$wins'),
              _Stat(label: 'Win rate', value: '${(winRate * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
