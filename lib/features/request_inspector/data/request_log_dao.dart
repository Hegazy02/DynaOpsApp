/// `RequestLogDao`: the `request_log` ring buffer — insert (trimming to the
/// newest [maxRows]), list newest first, clear.
///
/// Why it exists: the shared database is the only store both isolates see, so
/// uploads sent by the tracking service show up in the UI isolate's inspector.
/// Status: used — by `RequestLogInterceptor` (both isolates) and
/// `RequestInspectorRepository`; tested in
/// `test/features/request_inspector/data/request_log_dao_test.dart`.
library;

import 'package:sqflite/sqflite.dart';

import 'request_log_entry_model.dart';

class RequestLogDao {
  RequestLogDao(this._db, {this.maxRows = 300});
  final Database _db;
  final int maxRows;

  static const _table = 'request_log';

  Future<void> insert(RequestLogEntryModel entry) async {
    await _db.insert(_table, entry.toRow());
    await _db.rawDelete(
      'DELETE FROM $_table WHERE id NOT IN (SELECT id FROM $_table ORDER BY id DESC LIMIT ?)',
      [maxRows],
    );
  }

  Future<List<RequestLogEntryModel>> recent({int limit = 300}) async {
    final rows = await _db.query(_table, orderBy: 'id DESC', limit: limit);
    return rows.map(RequestLogEntryModel.fromRow).toList();
  }

  Future<void> clear() => _db.delete(_table);
}
