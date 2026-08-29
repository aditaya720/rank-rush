import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/security/provably_fair.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../game/domain/game_round.dart';
import 'fairness_providers.dart';

/// Lets a player independently recompute a finished round on-device and confirm
/// the server didn't cheat. The heavy lifting lives in the dependency-free
/// [ProvablyFair] engine — this screen is just a presentation of its output.
class FairnessScreen extends ConsumerStatefulWidget {
  const FairnessScreen({super.key, this.round});

  /// Optionally pre-loaded from the game screen's "Verify this round" button.
  final GameRound? round;

  @override
  ConsumerState<FairnessScreen> createState() => _FairnessScreenState();
}

class _FairnessScreenState extends ConsumerState<FairnessScreen> {
  final _seedCtrl = TextEditingController();
  final _roundIdCtrl = TextEditingController();
  FairRound? _manualRound;
  String? _manualError;
  bool _manualExpanded = false;

  @override
  void dispose() {
    _seedCtrl.dispose();
    _roundIdCtrl.dispose();
    super.dispose();
  }

  void _runManual() {
    final seed = _seedCtrl.text.trim();
    final roundId = _roundIdCtrl.text.trim();
    if (seed.isEmpty || roundId.isEmpty) {
      setState(() {
        _manualError = 'Enter both a server seed and a round id.';
        _manualRound = null;
      });
      return;
    }
    try {
      final round = ProvablyFair.computeRound(seed, roundId);
      setState(() {
        _manualRound = round;
        _manualError = null;
      });
    } catch (e) {
      setState(() {
        _manualError = 'Could not compute this round: $e';
        _manualRound = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefer the round we were handed; otherwise show the latest settled round.
    final passedRound = widget.round;
    final latest = ref.watch(lastFinishedRoundProvider);

    final GameRound? target = passedRound ?? latest.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Provable fairness')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _HowItWorks(),
            const SizedBox(height: 16),
            if (target != null)
              _AutoVerification(round: target)
            else if (passedRound == null && latest.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingView(message: 'Finding a settled round…'),
              )
            else
              const _NoRoundYet(),
            const SizedBox(height: 16),
            _ManualSection(
              expanded: _manualExpanded,
              onToggle: () =>
                  setState(() => _manualExpanded = !_manualExpanded),
              seedCtrl: _seedCtrl,
              roundIdCtrl: _roundIdCtrl,
              onRun: _runManual,
              error: _manualError,
              result: _manualRound,
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'How this works',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Before every round the server publishes SHA-256(serverSeed) — a '
            'commitment it cannot change afterwards. When the round ends it '
            'reveals the seed. Because the entire deck is derived deterministically '
            'from the seed and the round id, your device can rebuild the deck and '
            'confirm the target card and winner were fixed in advance.',
            style: TextStyle(color: AppColors.textMuted, height: 1.4, fontSize: 13),
          ),
          SizedBox(height: 8),
          Text(
            'Every check below runs entirely on your phone — no server involved.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoVerification extends StatelessWidget {
  const _AutoVerification({required this.round});
  final GameRound round;

  @override
  Widget build(BuildContext context) {
    final seed = round.serverSeed;
    if (seed == null || seed.isEmpty) {
      return const _NotSettled();
    }

    final result = ProvablyFair.verify(
      serverSeed: seed,
      roundId: round.id,
      reportedServerSeedHash: round.serverSeedHash,
      reportedDeckHash: round.deckHash ?? '',
      reportedWinner: round.winner?.wire ?? '',
      reportedTargetCode: round.targetCard?.code ?? '',
    );

    return SectionCard(
      title: 'Round ${round.id}',
      trailing: _VerdictChip(isValid: result.isValid),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CheckRow(
            ok: result.seedHashMatches,
            label: 'Revealed seed hashes to the pre-round commitment',
          ),
          _CheckRow(
            ok: result.deckHashMatches,
            label: 'Rebuilt deck matches the reported deck hash',
          ),
          _CheckRow(
            ok: result.targetMatches,
            label: 'Target card matches (${result.recomputed.targetCard.code})',
          ),
          _CheckRow(
            ok: result.winnerMatches,
            label: 'Winner matches (${result.recomputed.winner.wire.toUpperCase()})',
          ),
          const Divider(height: 28),
          _HashField(label: 'Committed hash', value: round.serverSeedHash),
          _HashField(label: 'Revealed seed', value: seed),
          _HashField(label: 'Deck hash', value: result.recomputed.deckHash),
          const SizedBox(height: 14),
          const Text('Recomputed reveal',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          _RevealCodes(round: result.recomputed),
        ],
      ),
    );
  }
}

class _RevealCodes extends StatelessWidget {
  const _RevealCodes({required this.round});
  final FairRound round;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final step in round.revealSequence)
          _CodeChip(
            code: step.card.code,
            side: step.side,
            isWinner: step.index == round.winningIndex,
          ),
      ],
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({
    required this.code,
    required this.side,
    required this.isWinner,
  });

  final String code;
  final RevealSide side;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final sideColor = side == RevealSide.left ? AppColors.left : AppColors.right;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isWinner
            ? AppColors.win.withValues(alpha: 0.18)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWinner ? AppColors.win : sideColor.withValues(alpha: 0.5),
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            side == RevealSide.left ? 'L' : 'R',
            style: TextStyle(
                color: sideColor, fontWeight: FontWeight.w800, fontSize: 11),
          ),
          const SizedBox(width: 6),
          Text(code,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.ok, required this.label});
  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.cancel,
            color: ok ? AppColors.win : AppColors.loss,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13.5, height: 1.3)),
          ),
        ],
      ),
    );
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.isValid});
  final bool isValid;

  @override
  Widget build(BuildContext context) {
    final color = isValid ? AppColors.win : AppColors.loss;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isValid ? 'VERIFIED' : 'MISMATCH',
        style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1),
      ),
    );
  }
}

class _HashField extends StatelessWidget {
  const _HashField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11.5)),
              const Spacer(),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.copy, size: 14, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualSection extends StatelessWidget {
  const _ManualSection({
    required this.expanded,
    required this.onToggle,
    required this.seedCtrl,
    required this.roundIdCtrl,
    required this.onRun,
    required this.error,
    required this.result,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController seedCtrl;
  final TextEditingController roundIdCtrl;
  final VoidCallback onRun;
  final String? error;
  final FairRound? result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Verify manually',
      trailing: IconButton(
        icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
        onPressed: onToggle,
      ),
      child: !expanded
          ? const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Paste any round’s server seed and id to rebuild it yourself.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: seedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Server seed (revealed)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roundIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Round id',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Rebuild round'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!,
                      style: const TextStyle(color: AppColors.loss, fontSize: 12.5)),
                ],
                if (result != null) ...[
                  const Divider(height: 28),
                  _HashField(
                      label: 'SHA-256(seed)', value: result!.serverSeedHash),
                  _HashField(label: 'Deck hash', value: result!.deckHash),
                  const SizedBox(height: 6),
                  Text(
                    'Target ${result!.targetCard.code} · '
                    'winner ${result!.winner.wire.toUpperCase()} · '
                    '${result!.revealSequence.length} cards revealed',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  _RevealCodes(round: result!),
                ],
              ],
            ),
    );
  }
}

class _NotSettled extends StatelessWidget {
  const _NotSettled();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: const [
          Icon(Icons.hourglass_bottom, color: AppColors.textMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This round hasn’t revealed its seed yet. Come back once it has '
              'finished to verify it.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoRoundYet extends StatelessWidget {
  const _NoRoundYet();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Row(
        children: const [
          Icon(Icons.inbox_outlined, color: AppColors.textMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No settled rounds to verify yet. Play a round, or paste a seed '
              'below to verify manually.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
