/// Opens a fresh in-memory `AppDatabase` through `sqflite_common_ffi`, so DAO
/// and sync tests run real SQL on the desktop test runner.
///
/// Status: active — shared by the database, DAO and sync tests.
library;

import 'package:dynaopsapp/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> openTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
}
