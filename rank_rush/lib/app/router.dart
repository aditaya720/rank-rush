import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/sign_in_screen.dart';
import '../features/fairness/presentation/fairness_screen.dart';
import '../features/game/domain/game_round.dart';
import '../features/game/presentation/game_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/leaderboard/presentation/leaderboard_screen.dart';
import '../features/responsible_play/presentation/responsible_play_screen.dart';
import '../features/shared/providers/firebase_providers.dart';
import '../features/wallet/presentation/wallet_screen.dart';

class Routes {
  const Routes._();
  static const String signIn = '/signin';
  static const String home = '/';
  static const String game = '/game';
  static const String wallet = '/wallet';
  static const String leaderboard = '/leaderboard';
  static const String fairness = '/fairness';
  static const String responsible = '/responsible';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: GoRouterRefreshStream(
      ref.watch(firebaseAuthProvider).authStateChanges(),
    ),
    redirect: (context, state) {
      final signedIn = authState.valueOrNull != null;
      final onSignIn = state.matchedLocation == Routes.signIn;

      // While auth is still resolving, don't bounce the user around.
      if (authState.isLoading) return null;

      if (!signedIn) return onSignIn ? null : Routes.signIn;
      if (onSignIn) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: Routes.home, builder: (_, __) => const HomeScreen()),
      GoRoute(path: Routes.game, builder: (_, __) => const GameScreen()),
      GoRoute(path: Routes.wallet, builder: (_, __) => const WalletScreen()),
      GoRoute(path: Routes.leaderboard, builder: (_, __) => const LeaderboardScreen()),
      GoRoute(
        path: Routes.fairness,
        builder: (_, state) =>
            FairnessScreen(round: state.extra is GameRound ? state.extra as GameRound : null),
      ),
      GoRoute(path: Routes.responsible, builder: (_, __) => const ResponsiblePlayScreen()),
    ],
  );
});

/// Bridges a [Stream] to a [Listenable] so GoRouter re-evaluates redirects when
/// auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
