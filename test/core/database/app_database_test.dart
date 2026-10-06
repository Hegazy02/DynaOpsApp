/// Tests that `AppDatabase` creates every migration's tables at the current
/// schema version (`user_version`).
///
/// Status: active — part of `flutter test`.
library;

import 'package:dynaopsapp/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

void main() {
  test('creates the v1 stores at the current schema version', () async {
    final database = await openTestDatabase();
    final version = (await database.db.rawQuery('PRAGMA user_version')).first.values.first;
    final tables = (await database.db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'"))
        .map((r) => r['name'])
        .toSet();
    expect(version, AppDatabase.schemaVersion);
    expect(tables, containsAll(['location_points', 'sync_meta']));
    await database.close();
  });
}
