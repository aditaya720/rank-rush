import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../shared/providers/firebase_providers.dart';
import '../domain/leaderboard_entry.dart';
import 'leaderboard_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Top coins'),
              Tab(text: 'Weekly wins'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _LeaderboardList(
                provider: topByBalanceProvider,
                valueOf: (e) => Formatters.coins(e.virtualCoinBalance),
                caption: 'coins',
              ),
              _LeaderboardList(
                provider: topByWeeklyWinsProvider,
                valueOf: (e) => '${e.weeklyWins}',
                caption: 'wins',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardList extends ConsumerWidget {
  const _LeaderboardList({
    required this.provider,
    required this.valueOf,
    required this.caption,
  });

  final ProviderListenable<AsyncValue<List<LeaderboardEntry>>> provider;
  final String Function(LeaderboardEntry) valueOf;
  final String caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final myUid = ref.watch(currentUidProvider);

    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: mapError(e).message),
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            child: Text('No players ranked yet.',
                style: TextStyle(color: AppColors.textMuted)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final entry = entries[i];
            return _LeaderboardRow(
              rank: i + 1,
              entry: entry,
              value: valueOf(entry),
              caption: caption,
              isMe: entry.uid == myUid,
            );
          },
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.value,
    required this.caption,
    required this.isMe,
  });

  final int rank;
  final LeaderboardEntry entry;
  final String value;
  final String caption;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.feltBright.withValues(alpha: 0.14) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? AppColors.feltBright.withValues(alpha: 0.6)
              : const Color(0x14FFFFFF),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: _RankBadge(rank: rank)),
          const SizedBox(width: 10),
          _Avatar(name: entry.displayName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const Text('you',
                          style: TextStyle(
                              color: AppColors.feltBright,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
                Text('${entry.totalWins} total wins',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.gold)),
              Text(caption,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});
  final int rank;

  @override
  Widget build(BuildContext context) {
    Color? medal;
    if (rank == 1) medal = AppColors.gold;
    if (rank == 2) medal = const Color(0xFFC0C7D0);
    if (rank == 3) medal = const Color(0xFFCD7F32);

    return Text(
      '$rank',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 16,
        color: medal ?? AppColors.textMuted,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    // Deterministic hue from the name so avatars are stable and varied.
    final hue = (name.hashCode % 360).abs().toDouble();
    final color = HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        initial,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
