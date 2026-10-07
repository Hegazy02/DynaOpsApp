/// `AppDatabase`: opens the single sqflite file (WAL) and applies the ordered
/// migration list, using SQLite's `user_version` as the schema version (§9).
///
/// Why it exists: one place owns the schema so new stores (FUTURE outbox,
/// reference cache, §10.2) are just the next entry in [migrations].
/// Status: used — opened once per isolate (UI and tracking service) by the
/// service locators; DAOs live in their features. Tested in
/// `test/core/database/app_database_test.dart`.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  static const fileName = 'dynaops.db';

  final Database db;

  /// One entry per schema version; index 0 is version 1. Never edit a shipped
  /// entry — append a new one.
  static const List<List<String>> migrations = [
    [
      '''
      CREATE TABLE location_points (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy REAL NOT NULL,
        speed REAL,
        heading REAL,
        is_mocked INTEGER NOT NULL DEFAULT 0,
        captured_at INTEGER NOT NULL,
        state TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        retryable INTEGER NOT NULL DEFAULT 1,
        last_error TEXT,
        batch_id TEXT,
        created_at INTEGER NOT NULL
      )
      ''',
      'CREATE INDEX idx_points_user_state_time ON location_points (user_id, state, captured_at)',
      'CREATE TABLE sync_meta (key TEXT PRIMARY KEY, value TEXT)',
    ],
    [
      '''
      CREATE TABLE request_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source TEXT NOT NULL,
        method TEXT NOT NULL,
        url TEXT NOT NULL,
        request_headers TEXT,
        request_body TEXT,
        status_code INTEGER,
        response_body TEXT,
        error TEXT,
        started_at INTEGER NOT NULL,
        duration_ms INTEGER NOT NULL
      )
      ''',
    ],
  ];

  static int get schemaVersion => migrations.length;

  /// Opens (and migrates) the database. [path] and [factory] exist for tests.
  static Future<AppDatabase> open({String? path, DatabaseFactory? factory}) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await dbFactory.getDatabasesPath(), fileName);
    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        // Two isolates (UI + tracking service) open the same file.
        onConfigure: (db) => db.rawQuery('PRAGMA journal_mode=WAL'),
        onCreate: (db, version) => _migrate(db, 0, version),
        onUpgrade: _migrate,
      ),
    );
    return AppDatabase._(db);
  }

  static Future<void> _migrate(Database db, int from, int to) async {
    for (var version = from; version < to; version++) {
      final batch = db.batch();
      for (final statement in migrations[version]) {
        batch.execute(statement);
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> close() => db.close();
}
