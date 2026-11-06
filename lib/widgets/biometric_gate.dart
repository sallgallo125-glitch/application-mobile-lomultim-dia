import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/account_providers.dart';
import '../features/biometric/biometric_providers.dart';
import '../theme/tokens.dart';

/// True only when the sensitive content must be behind Face ID / fingerprint:
/// signed in + quick sign-in enabled. Fails open when the device no longer
/// has usable biometrics, so the user can never be locked out for good.
final biometricLockProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(signedInProvider)) return false;
  final enabled = await ref.watch(biometricLoginProvider.future) != null;
  if (!enabled) return false;
  return ref.watch(biometricAvailableProvider.future);
});

/// Wraps sensitive content behind the system biometric prompt. The prompt is
/// shown once per screen visit; when refused, a locked state offers retry.
class BiometricGate extends ConsumerStatefulWidget {
  const BiometricGate({super.key, required this.child, this.reason});
  final Widget child;

  /// OS prompt text; defaults to the activation codes wording.
  final String? reason;

  @override
  ConsumerState<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends ConsumerState<BiometricGate> {
  bool _prompted = false;
  bool _unlocked = false;
  bool _failed = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(biometricLockProvider);
    return locked.when(
      loading: () => const SizedBox.expand(),
      error: (_, __) => widget.child,
      data: (mustLock) {
        if (!mustLock || _unlocked) return widget.child;
        if (!_prompted) {
          _prompted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
        }
        return _lockedUi();
      },
    );
  }

  Future<void> _authenticate() async {
    if (_busy || _unlocked || !mounted) return;
    setState(() => _busy = true);
    final ok = await ref.read(biometricActionsProvider).tryUnlock(
        reason: widget.reason ??
            'Authentifiez-vous pour voir vos codes d’activation.');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failed = !ok;
      _unlocked = ok;
    });
  }

  Widget _lockedUi() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fingerprint, size: 52, color: AppColors.primary),
            const SizedBox(height: AppSpacing.md),
            const Text('Contenu protégé', style: AppText.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Text(
                _failed
                    ? 'Authentification refusée. Réessayez ou utilisez votre mot de passe à la connexion.'
                    : 'Utilisez l’empreinte ou Face ID pour afficher ce contenu.',
                textAlign: TextAlign.center,
                style: AppText.bodyMuted),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 48),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              onPressed: _busy ? null : _authenticate,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(AppColors.white)))
                  : const Text('Déverrouiller'),
            ),
          ]),
        ),
      );
}
