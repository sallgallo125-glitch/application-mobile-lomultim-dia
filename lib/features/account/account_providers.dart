import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/repositories/account_repository.dart';
import '../../contracts/account.dart';
import '../home/home_providers.dart';
import '../persistence.dart';

final accountRepositoryProvider = Provider<AccountRepository>(
    (ref) => AccountRepository(ref.watch(apiClientProvider)));
final accountSummaryProvider = FutureProvider<AccountSummary>(
    (ref) => ref.watch(accountRepositoryProvider).getSummary());
final ordersProvider = FutureProvider<List<OrderSummary>>(
    (ref) => ref.watch(accountRepositoryProvider).listOrders());
final orderDetailProvider = FutureProvider.family<OrderDetail, String>(
    (ref, number) => ref.watch(accountRepositoryProvider).getOrder(number));

class SessionUser {
  const SessionUser({required this.name, required this.phone});
  final String name;
  final String phone;
}

/// Signed-in customer, kept on the device between launches.
final sessionUserProvider =
    StateNotifierProvider<StateController<SessionUser?>, SessionUser?>((ref) {
  const key = 'session_user';
  final controller = StateController<SessionUser?>(readStored(ref, key, (json) {
    final m = json as Map<String, dynamic>;
    return SessionUser(name: m['name'] as String, phone: m['phone'] as String);
  }));
  controller.addListener(
      (next) => writeStored(ref, key,
          next == null ? null : {'name': next.name, 'phone': next.phone}),
      fireImmediately: false);
  return controller;
});

/// Customer account created in the app (mock until the real auth API).
class RegisteredAccount {
  const RegisteredAccount(
      {required this.firstName,
      required this.lastName,
      required this.email,
      required this.phone,
      required this.address,
      required this.password});
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String address;

  /// Salted hash from [hashPassword] (`pbkdf2$...`). Older builds stored a
  /// salted SHA-256 or the plain password; [verifyPassword] accepts them
  /// and [upgradeStoredPassword] replaces them at the next sign-in.
  final String password;

  String get fullName => '$firstName $lastName';
  String get phoneDigits => phone.replaceAll(RegExp(r'\D'), '');

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'address': address,
        'password': password,
      };
  factory RegisteredAccount.fromJson(Map<String, dynamic> j) =>
      RegisteredAccount(
          firstName: j['firstName'] as String,
          lastName: j['lastName'] as String,
          email: j['email'] as String,
          phone: j['phone'] as String,
          address: j['address'] as String,
          password: j['password'] as String);
}

/// Demo account, always available: demo@lomultimedia.com or 77 000 00 00,
/// password "lo123456".
const demoAccount = RegisteredAccount(
    firstName: 'Aïssatou',
    lastName: 'Diop',
    email: 'demo@lomultimedia.com',
    phone: '77 000 00 00',
    address: 'Sacré-Cœur 3, Dakar',
    password: 'lo123456');

/// Accounts created on this device (mock auth), kept between launches.
final registeredAccountsProvider = StateNotifierProvider<
    StateController<List<RegisteredAccount>>, List<RegisteredAccount>>((ref) {
  const key = 'registered_accounts';
  final controller = StateController<List<RegisteredAccount>>(readStored(
          ref,
          key,
          (json) => [
                for (final a in json as List<dynamic>)
                  RegisteredAccount.fromJson(a as Map<String, dynamic>)
              ]) ??
      const <RegisteredAccount>[]);
  controller.addListener(
      (next) => writeStored(ref, key, [for (final a in next) a.toJson()]),
      fireImmediately: false);
  return controller;
});

const _legacyPrefix = 'sha256';
const _pbkdf2Prefix = 'pbkdf2';

/// PBKDF2-HMAC-SHA256 rounds. Pure Dart, so kept to a value that stays
/// well under a second on entry-level phones while making each guess
/// tens of thousands of times costlier than a single SHA-256.
const pbkdf2Iterations = 60000;

String _legacyDigest(String salt, String password) =>
    sha256.convert(utf8.encode('$salt:$password')).toString();

/// PBKDF2-HMAC-SHA256, one 32-byte block (RFC 8018).
List<int> _pbkdf2(String password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(password));
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final out = List<int>.of(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

/// Compares without stopping at the first difference (no timing leak).
bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Salted PBKDF2 so the local database never holds a readable password:
/// `pbkdf2$iterations$salt$hash` (base64url).
String hashPassword(String password) {
  final random = Random.secure();
  final salt = List<int>.generate(16, (_) => random.nextInt(256));
  final hash = _pbkdf2(password, salt, pbkdf2Iterations);
  return '$_pbkdf2Prefix\$$pbkdf2Iterations\$${base64Url.encode(salt)}'
      '\$${base64Url.encode(hash)}';
}

/// True when [stored] is not in the current format and should be replaced
/// by [hashPassword] at the next successful sign-in.
bool needsRehash(String stored) {
  final parts = stored.split(r'$');
  return !(parts.length == 4 &&
      parts[0] == _pbkdf2Prefix &&
      int.tryParse(parts[1]) == pbkdf2Iterations);
}

/// Checks [password] against a value stored by [hashPassword], by older
/// builds (salted SHA-256) or as legacy plain text.
bool verifyPassword(String stored, String password) {
  final parts = stored.split(r'$');
  try {
    if (parts.length == 4 && parts[0] == _pbkdf2Prefix) {
      final iterations = int.parse(parts[1]);
      final salt = base64Url.decode(parts[2]);
      final expected = base64Url.decode(parts[3]);
      return _constantTimeEquals(
          _pbkdf2(password, salt, iterations), expected);
    }
    if (parts.length == 3 && parts[0] == _legacyPrefix) {
      return _constantTimeEquals(utf8.encode(parts[2]),
          utf8.encode(_legacyDigest(parts[1], password)));
    }
  } on FormatException {
    return false;
  }
  return _constantTimeEquals(utf8.encode(stored), utf8.encode(password));
}

/// Replaces an outdated stored password of [account] by a fresh hash, once
/// [password] has just been verified. The demo account is left as is.
void upgradeStoredPassword(
    WidgetRef ref, RegisteredAccount account, String password) {
  if (!needsRehash(account.password)) return;
  final controller = ref.read(registeredAccountsProvider.notifier);
  if (!controller.state.any((a) => identical(a, account))) return;
  final upgraded = RegisteredAccount(
      firstName: account.firstName,
      lastName: account.lastName,
      email: account.email,
      phone: account.phone,
      address: account.address,
      password: hashPassword(password));
  controller.state = [
    for (final a in controller.state) identical(a, account) ? upgraded : a
  ];
}

/// Account matching [identifier] (e-mail or phone) and [password], or null.
RegisteredAccount? findAccount(
    List<RegisteredAccount> accounts, String identifier, String password) {
  final id = identifier.trim().toLowerCase();
  final digits = id.replaceAll(RegExp(r'\D'), '');
  for (final a in [demoAccount, ...accounts]) {
    final matches = a.email.toLowerCase() == id ||
        (digits.length >= 9 &&
            a.phoneDigits.endsWith(digits.substring(digits.length - 9)));
    if (matches && verifyPassword(a.password, password)) return a;
  }
  return null;
}

/// Contact details of the last guest order (no account), kept on the device
/// to pre-fill the next checkout.
class GuestContact {
  const GuestContact({required this.name, required this.phone, this.address});
  final String name;
  final String phone;
  final String? address;
}

final guestContactProvider =
    StateNotifierProvider<StateController<GuestContact?>, GuestContact?>((ref) {
  const key = 'guest_contact';
  final controller =
      StateController<GuestContact?>(readStored(ref, key, (json) {
    final m = json as Map<String, dynamic>;
    return GuestContact(
        name: m['name'] as String,
        phone: m['phone'] as String,
        address: m['address'] as String?);
  }));
  controller.addListener(
      (next) => writeStored(
          ref,
          key,
          next == null
              ? null
              : {
                  'name': next.name,
                  'phone': next.phone,
                  'address': next.address
                }),
      fireImmediately: false);
  return controller;
});

/// An order placed without an account, kept on this device so the guest
/// can find and track it later.
class GuestOrder {
  const GuestOrder(
      {required this.number,
      required this.createdAt,
      required this.totalXof,
      required this.phone,
      required this.status});
  final String number;
  final String createdAt;
  final int totalXof;
  final String phone;
  final String status;

  Map<String, dynamic> toJson() => {
        'number': number,
        'createdAt': createdAt,
        'totalXof': totalXof,
        'phone': phone,
        'status': status,
      };
  factory GuestOrder.fromJson(Map<String, dynamic> j) => GuestOrder(
      number: j['number'] as String,
      createdAt: j['createdAt'] as String,
      totalXof: (j['totalXof'] as num).toInt(),
      phone: j['phone'] as String,
      status: j['status'] as String);
}

/// Guest orders placed on this device, most recent first (max 30).
final guestOrdersProvider =
    StateNotifierProvider<StateController<List<GuestOrder>>, List<GuestOrder>>(
        (ref) {
  const key = 'guest_orders';
  final controller = StateController<List<GuestOrder>>(readStored(
          ref,
          key,
          (json) => [
                for (final o in json as List<dynamic>)
                  GuestOrder.fromJson(o as Map<String, dynamic>)
              ]) ??
      const <GuestOrder>[]);
  controller.addListener(
      (next) => writeStored(ref, key, [for (final o in next) o.toJson()]),
      fireImmediately: false);
  return controller;
});

final signedInProvider =
    Provider<bool>((ref) => ref.watch(sessionUserProvider) != null);

/// Delivery address and zone of the customer's last order, per account
/// (keyed by phone), kept on the device to pre-fill the next checkout.
final lastDeliveryProvider = StateNotifierProvider.family<
    StateController<({String address, String zoneId})?>,
    ({String address, String zoneId})?,
    String>((ref, account) {
  final key = 'last_delivery_$account';
  final controller = StateController<({String address, String zoneId})?>(
      readStored(ref, key, (json) {
    final m = json as Map<String, dynamic>;
    return (address: m['address'] as String, zoneId: m['zoneId'] as String);
  }));
  controller.addListener(
      (next) => writeStored(
          ref,
          key,
          next == null
              ? null
              : {'address': next.address, 'zoneId': next.zoneId}),
      fireImmediately: false);
  return controller;
});
