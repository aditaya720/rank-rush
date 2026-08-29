import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/common.dart';
import 'auth_controller.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(mapError(next.error!).message)),
          );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _BrandHero(),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => ref.read(authControllerProvider.notifier).signInAsGuest(),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play as guest'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 24),
                  if (isBusy) const LinearProgressIndicator(),
                  const SizedBox(height: 24),
                  const VirtualCoinNotice(),
                  const SizedBox(height: 12),
                  Text(
                    'You must be 18+ to play. This game is for entertainment only '
                    'and involves no real-money gambling.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.feltBright, AppColors.felt],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.felt.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.style_rounded, size: 46, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Rank Rush',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pick a side. Watch the reveal. Provably fair.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
