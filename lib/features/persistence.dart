import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common/sqlite_api.dart';

/// Small persistence contract kept separate from SQLite so the temporary
/// local backend can be replaced by the production API without UI changes.
abstract interface class LocalPersistence {
  String? read(String key);
  Future<void> write(String key, String? value);
}

/// Development-only SQLite storage for local accounts, test orders, cart
/// contents, and small user preferences. Do not use as production auth.
class SqliteLocalPersistence implements LocalPersistence {
  SqliteLocalPersistence._(this._database);

  final Database _database;
  final Map<String, String> _snapshot = {};
  Future<void> _writeQueue = Future<void>.value();

  static Future<SqliteLocalPersistence> open() async {
    final path = p.join(
      await sqflite.getDatabasesPath(),
      'lomultimedia_test.sqlite',
    );
    return openWith(sqflite.databaseFactory, path);
  }

  @visibleForTesting
  static Future<SqliteLocalPersistence> openWith(
    DatabaseFactory factory,
    String path,
  ) async {
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE local_accounts (
              email TEXT PRIMARY KEY COLLATE NOCASE,
              phone TEXT NOT NULL UNIQUE,
              first_name TEXT NOT NULL,
              last_name TEXT NOT NULL,
              address TEXT NOT NULL,
              password TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE local_orders (
              order_number TEXT PRIMARY KEY,
              position INTEGER NOT NULL,
              payload_json TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE local_cart_items (
              item_id TEXT PRIMARY KEY,
              position INTEGER NOT NULL,
              payload_json TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE local_state (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    final store = SqliteLocalPersistence._(database);
    await store._refreshSnapshot();
    return store;
  }

  @override
  String? read(String key) => _snapshot[key];

  @override
  Future<void> write(String key, String? value) {
    final previous = _snapshot[key];
    if (value == null) {
      _snapshot.remove(key);
    } else {
      _snapshot[key] = value;
    }
    final operation = _writeQueue.then((_) => _writeToDatabase(key, value));
    // Keep the queue usable after an error; callers still receive and report
    // the original operation failure below.
    _writeQueue = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation.catchError((Object error, StackTrace stackTrace) {
      if (_snapshot[key] == value) {
        if (previous == null) {
          _snapshot.remove(key);
        } else {
          _snapshot[key] = previous;
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> _writeToDatabase(String key, String? value) async {
    switch (key) {
      case 'registered_accounts':
        await _writeAccounts(value);
        return;
      case 'mock_member_orders':
        await _writeJsonRows(
          table: 'local_orders',
          idColumn: 'order_number',
          key: key,
          value: value,
        );
        return;
      case 'mock_cart_items':
        await _writeJsonRows(
          table: 'local_cart_items',
          idColumn: 'item_id',
          key: key,
          value: value,
        );
        return;
      default:
        if (value == null) {
          await _database
              .delete('local_state', where: 'key = ?', whereArgs: [key]);
        } else {
          await _database.insert(
            'local_state',
            {'key': key, 'value': value},
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
    }
    await _refreshKeySnapshot(key);
  }

  Future<void> _writeAccounts(String? value) async {
    await _database.transaction((transaction) async {
      await transaction.delete('local_accounts');
      if (value == null) return;
      final accounts = jsonDecode(value) as List<dynamic>;
      final batch = transaction.batch();
      for (final account in accounts) {
        final row = account as Map<String, dynamic>;
        batch.insert(
          'local_accounts',
          {
            'email': row['email'],
            'phone': row['phone'],
            'first_name': row['firstName'],
            'last_name': row['lastName'],
            'address': row['address'],
            'password': row['password'],
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> _writeJsonRows({
    required String table,
    required String idColumn,
    required String key,
    required String? value,
  }) async {
    await _database.transaction((transaction) async {
      await transaction.delete(table);
      if (value == null) return;
      final rows = jsonDecode(value) as List<dynamic>;
      final batch = transaction.batch();
      for (var index = 0; index < rows.length; index++) {
        final row = Map<String, dynamic>.from(rows[index] as Map);
        final id = key == 'mock_member_orders'
            ? row['number'] as String
            : row['id'] as String;
        batch.insert(table, {
          idColumn: id,
          'position': index,
          'payload_json': jsonEncode(row),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> _refreshSnapshot() async {
    final state = await _database.query('local_state');
    for (final row in state) {
      _snapshot[row['key'] as String] = row['value'] as String;
    }
    await _refreshKeySnapshot('registered_accounts');
    await _refreshKeySnapshot('mock_member_orders');
    await _refreshKeySnapshot('mock_cart_items');
  }

  Future<void> _refreshKeySnapshot(String key) async {
    switch (key) {
      case 'registered_accounts':
        final rows = await _database.query('local_accounts', orderBy: 'rowid');
        if (rows.isEmpty) {
          _snapshot.remove(key);
        } else {
          _snapshot[key] = jsonEncode([
            for (final row in rows)
              {
                'firstName': row['first_name'],
                'lastName': row['last_name'],
                'email': row['email'],
                'phone': row['phone'],
                'address': row['address'],
                'password': row['password'],
              }
          ]);
        }
        return;
      case 'mock_member_orders':
        await _refreshJsonRows('local_orders', key);
        return;
      case 'mock_cart_items':
        await _refreshJsonRows('local_cart_items', key);
        return;
      default:
        final rows = await _database.query(
          'local_state',
          columns: ['value'],
          where: 'key = ?',
          whereArgs: [key],
          limit: 1,
        );
        if (rows.isEmpty) {
          _snapshot.remove(key);
        } else {
          _snapshot[key] = rows.first['value'] as String;
        }
    }
  }

  Future<void> _refreshJsonRows(String table, String key) async {
    final rows = await _database.query(table, orderBy: 'position');
    if (rows.isEmpty) {
      _snapshot.remove(key);
    } else {
      _snapshot[key] = jsonEncode([
        for (final row in rows)
          jsonDecode(row['payload_json'] as String) as Map<String, dynamic>
      ]);
    }
  }

  Future<void> migrateFrom(SharedPreferences preferences) async {
    const legacyKeys = [
      'session_user',
      'registered_accounts',
      'guest_contact',
      'guest_orders',
      'favorite_ids',
      'recently_viewed',
      'recent_searches',
      'shop_filters',
      'notifications',
      'chat_messages',
      'sav_tickets',
    ];
    for (final key in legacyKeys) {
      final value = preferences.getString(key);
      if (value != null && read(key) == null) {
        await write(key, value);
      }
      await preferences.remove(key);
    }
  }

  @visibleForTesting
  Future<void> close() async {
    await _writeQueue;
    await _database.close();
  }
}

final localPersistenceProvider = Provider<LocalPersistence?>((ref) => null);

/// Retained only as an in-memory test fallback and for one-time migration of
/// values written by older builds. The running app uses SQLite.
final preferencesProvider = Provider<SharedPreferences?>((ref) => null);

T? readStored<T>(Ref ref, String key, T Function(Object? json) decode) {
  final raw = ref.read(localPersistenceProvider)?.read(key) ??
      ref.read(preferencesProvider)?.getString(key);
  if (raw == null) return null;
  try {
    return decode(jsonDecode(raw));
  } catch (error, stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'local persistence',
      context: ErrorDescription('while decoding stored "$key" data'),
    ));
    return null;
  }
}

void writeStored(Ref ref, String key, Object? value) {
  final storage = ref.read(localPersistenceProvider);
  final preferences = ref.read(preferencesProvider);
  if (storage == null) {
    if (preferences == null) return;
    if (value == null) {
      preferences.remove(key);
    } else {
      preferences.setString(key, jsonEncode(value));
    }
    return;
  }

  final encoded = value == null ? null : jsonEncode(value);
  storage.write(key, encoded).catchError((Object error, StackTrace stackTrace) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stackTrace,
      library: 'local persistence',
      context: ErrorDescription('while saving "$key" to SQLite'),
    ));
  });
}
