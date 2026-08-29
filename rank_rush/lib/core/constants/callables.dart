/// Names of the callable Cloud Functions. These MUST match the exported
/// function names in `functions/src/index.ts`.
class Callables {
  const Callables._();

  static const String ensureProfile = 'ensureProfileFn';
  static const String syncRound = 'syncRoundFn';
  static const String placeBet = 'placeBetFn';
  static const String claimDailyBonus = 'claimDailyBonusFn';
  static const String verifyFairness = 'verifyFairnessFn';
  static const String serverTime = 'serverTimeFn';
  static const String selfExclude = 'selfExcludeFn';

  // Admin (role-gated on the server).
  static const String adminCreateRound = 'adminCreateRoundFn';
  static const String adminCancelRound = 'adminCancelRoundFn';
  static const String adminSetConfig = 'adminSetConfigFn';
  static const String adminAdjustBalance = 'adminAdjustBalanceFn';
  static const String adminSetRole = 'adminSetRoleFn';
  static const String adminSuspendUser = 'adminSuspendUserFn';
}
