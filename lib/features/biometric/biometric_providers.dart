import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../account/account_providers.dart';

const _sessionKey = 'biometric_session';

/// Device-side primitives, kept behind interfaces so screens and tests never
/// touch the platform plugins directly.
abstract interface class BiometricAuthenticator {
  /// Face/fingerprint actually usable right now (hardware + enrollment).
  Future<bool> canAuthenticate();

  /// Shows the system prompt; [reason] is displayed by the OS.
  Future<bool> authenticate({required String reason});
}

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  @override
  Future<bool> canAuthenticate() async {
    try {
      final auth = LocalAuthentication();
      final available = await auth.getAvailableBiometrics();
      return available.isNotEmpty && await auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await LocalAuthentication().authenticate(
          localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}

/// Secrets live outside the app data (Keystore / Keychain), so a plain
/// backup or an extracted sandbox can never read them.
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) =>
      _storage.write(key: key, value: value);
}

final biometricAuthenticatorProvider =
    Provider<BiometricAuthenticator>((ref) => DeviceBiometricAuthenticator());

final secureStoreProvider =
    Provider<SecureKeyValueStore>((ref) => const FlutterSecureKeyValueStore());

final biometricAvailableProvider = FutureProvider<bool>(
    (ref) => ref.watch(biometricAuthenticatorProvider).canAuthenticate());

/// The identity saved when the user enabled the quick sign-in, or null.
final biometricLoginProvider = FutureProvider<SessionUser?>((ref) async {
  final raw = await ref.watch(secureStoreProvider).read(_sessionKey);
  if (raw == null) return null;
  try {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return SessionUser(name: m['name'] as String, phone: m['phone'] as String);
  } catch (_) {
    return null;
  }
});

/// Face ID button on the login screen: enrolled biometrics + a saved login.
final biometricQuickLoginAvailableProvider = FutureProvider<bool>((ref) async {
  final login = await ref.watch(biometricLoginProvider.future);
  if (login == null) return false;
  return ref.watch(biometricAvailableProvider.future);
});

class BiometricActions {
  BiometricActions(this.ref);

  final Ref ref;

  /// Saves [user] behind a biometric check, so only the device owner can
  /// turn the quick sign-in on. Returns false when refused or unsupported.
  Future<bool> enable(SessionUser user) async {
    try {
      final ok = await ref.read(biometricAuthenticatorProvider).authenticate(
          reason:
              'Authentifiez-vous pour activer la connexion Face ID / empreinte.');
      if (!ok) return false;
      await ref.read(secureStoreProvider).write(
          _sessionKey, jsonEncode({'name': user.name, 'phone': user.phone}));
      ref.invalidate(biometricLoginProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> disable() async {
    await ref.read(secureStoreProvider).write(_sessionKey, null);
    ref.invalidate(biometricLoginProvider);
  }

  /// Restores the saved login after a successful biometric check, or null.
  Future<SessionUser?> tryLogin() async {
    final login = await ref.read(biometricLoginProvider.future);
    if (login == null) return null;
    final ok = await ref.read(biometricAuthenticatorProvider).authenticate(
        reason: 'Authentifiez-vous pour vous connecter à LO Multimédia.');
    return ok ? login : null;
  }

  /// One-off unlock (codes screens). No persistence: each visit re-asks.
  Future<bool> tryUnlock({required String reason}) =>
      ref.read(biometricAuthenticatorProvider).authenticate(reason: reason);

  /// Keeps the stored identity in sync with the last classic sign-in when
  /// the quick sign-in is already enabled.
  Future<void> refreshStoredLogin(SessionUser user) async {
    try {
      final login = await ref.read(biometricLoginProvider.future);
      // Another account signing in on this device must not inherit the
      // quick sign-in enabled by the previous one.
      if (login == null || login.phone != user.phone) return;
      await ref.read(secureStoreProvider).write(
          _sessionKey, jsonEncode({'name': user.name, 'phone': user.phone}));
      ref.invalidate(biometricLoginProvider);
    } catch (_) {}
  }
}

final biometricActionsProvider =
    Provider<BiometricActions>((ref) => BiometricActions(ref));
