import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device storage, provided by `main()` once loaded. Null in tests and
/// until overridden: state then simply lives in memory.
final preferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Reads a JSON value saved under [key], or null.
T? readStored<T>(Ref ref, String key, T Function(Object? json) decode) {
  final raw = ref.read(preferencesProvider)?.getString(key);
  if (raw == null) return null;
  try {
    return decode(jsonDecode(raw));
  } catch (_) {
    return null; // corrupted / old format: start fresh
  }
}

/// Saves [value] as JSON under [key] (removes it when null).
void writeStored(Ref ref, String key, Object? value) {
  final prefs = ref.read(preferencesProvider);
  if (prefs == null) return;
  if (value == null) {
    prefs.remove(key);
  } else {
    prefs.setString(key, jsonEncode(value));
  }
}
