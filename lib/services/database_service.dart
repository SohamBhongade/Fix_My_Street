import 'package:mongo_dart/mongo_dart.dart';

import '../core/config.dart';
import '../models/report_model.dart';

class DatabaseException implements Exception {
  final String message;
  const DatabaseException(this.message);
  @override
  String toString() => message;
}

/// Singleton wrapper around MongoDB Atlas access for reports.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Db? _db;
  DbCollection? _reports;

  bool get _isOpen => _db?.state == State.open;

  Future<void> connect() async {
    if (_isOpen) return;

    _db = await Db.create(AppConfig.mongoUri);
    await _db!.open();
    _reports = _db!.collection(AppConfig.reportsCollection);
    print('[DB] Connected — database: "${_db!.databaseName}", collection: "${_reports!.collectionName}"');
  }

  Future<void> close() async {
    if (_db != null && _isOpen) {
      await _db!.close();
    }
    _db = null;
    _reports = null;
  }

  Future<DbCollection> _collection() async {
    if (!_isOpen || _reports == null) {
      await connect();
    }
    return _reports!;
  }

  /// Persists a new report. Returns the inserted document's ObjectId.
  /// Throws [DatabaseException] on connection or write failure.
  Future<ObjectId> saveReport(ReportModel report) async {
    try {
      // Re-open if the connection was dropped since last use.
      if (_db == null || !_isOpen) {
        print('[DB] Connection not open — reconnecting…');
        await connect();
      }

      final col = await _collection();

      final id = report.id ?? ObjectId();
      final payload = <String, dynamic>{
        '_id': id,
        'category': report.category,
        'severity': report.severity,
        'priority': report.priority.wire,
        'description': report.description,
        'latitude': report.latitude,
        'longitude': report.longitude,
        'address': report.address,
        'imageBase64': report.imageBase64,
        'status': report.status.wire,
        'createdAt': report.createdAt.toUtc().toIso8601String(),
        if (report.fixedAt != null)
          'fixedAt': report.fixedAt!.toUtc().toIso8601String(),
      };

      final result = await col.insertOne(payload);
      print('[DB] insertOne — success: ${result.isSuccess}, nInserted: ${result.nInserted}, id: $id');
      print('[DB] Wrote to DB="${_db!.databaseName}" collection="${col.collectionName}"');

      if (!result.isSuccess || result.nInserted == 0) {
        throw StateError('Insert failed: ${result.writeError?.errmsg ?? "nInserted=0"}');
      }
      return id;
    } catch (e) {
      print('[DB] saveReport error: $e');
      throw DatabaseException('Failed to save report: $e');
    }
  }

  /// Fetches all reports, newest first.
  Future<List<ReportModel>> fetchReports({bool onlyPending = false}) async {
    final col = await _collection();
    final selector = where.sortBy('createdAt', descending: true);
    if (onlyPending) {
      selector.eq('status', ReportStatus.pending.wire);
    }
    final docs = await col.find(selector).toList();
    return docs.map((d) => ReportModel.fromMap(d)).toList();
  }

  /// Updates a report's status. Stamps `fixedAt` when status becomes `fixed`.
  Future<bool> updateReportStatus(ObjectId id, ReportStatus status) async {
    final col = await _collection();
    final update = modify.set('status', status.wire);
    if (status == ReportStatus.fixed) {
      update.set('fixedAt', DateTime.now().toUtc().toIso8601String());
    } else {
      update.unset('fixedAt');
    }
    final result = await col.updateOne(where.id(id), update);
    return result.isSuccess && (result.nModified > 0 || result.nMatched > 0);
  }
}
