import 'package:mongo_dart/mongo_dart.dart';

import '../core/config.dart';
import '../models/app_user.dart';
import '../models/report_model.dart';

class DatabaseException implements Exception {
  final String message;
  const DatabaseException(this.message);
  @override
  String toString() => message;
}

/// Thrown when the verification pipeline rejects an operation — e.g. an
/// admin trying to volunteer for a high-severity task, or a non-admin
/// trying to flip a task from `pending_verification` to `resolved`.
///
/// Distinct from [DatabaseException] so UI code can surface a "rule
/// violation" message (orange, informative) rather than a generic
/// "database error" toast.
class VerificationRuleException implements Exception {
  final String message;
  const VerificationRuleException(this.message);
  @override
  String toString() => message;
}

/// Severity threshold above which a city admin cannot self-assign as a
/// volunteer (Rule A in the verification pipeline spec). Severity > 3 —
/// i.e. 4, 5, 6, …, 10 — is reserved for the public-works crews.
const int kAdminVolunteerSeverityCap = 3;

/// Singleton wrapper around MongoDB Atlas access for reports.
class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Db? _db;
  DbCollection? _reports;
  DbCollection? _users;

  // Cached in-flight handshake. Non-null while a connection attempt is
  // running; concurrent callers await this same future instead of starting
  // a second handshake against the same Db (which is what produced the
  // "state is State.OPENING" race at startup). Nulled on failure so a
  // retry starts fresh, and nulled by every teardown path (close / reopen
  // / _resetForReconnect) so a forced reconnect always re-runs the
  // handshake instead of short-circuiting on the stale completed future.
  Future<void>? _connectFuture;

  bool get _isOpen => _db?.state == State.open;

  /// Returns true if [e] looks like a transient TCP / driver-state issue
  /// that a fresh socket would likely fix. Matches on `toString()` because
  /// mongo_dart wraps several SocketException-shaped failures inside its
  /// own `MongoDartError` / `ConnectionException` without exposing a
  /// distinguishable type — so substring sniffing is the only portable
  /// signal we have.
  bool _isTransientConnectionError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('reset by peer') ||
        msg.contains('connection closed') ||
        msg.contains('no master connection') ||
        msg.contains('socket') ||
        msg.contains('broken pipe');
  }

  /// Runs [action]; if it throws a transient connection error, calls
  /// [reopen] for a clean socket and re-runs [action] **exactly once**.
  /// Non-connection failures (validation, write conflicts, real auth
  /// errors) propagate immediately — we only retry the failure modes a
  /// reconnect can actually fix.
  Future<T> _withReconnectRetry<T>(
    String op,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (e) {
      if (!_isTransientConnectionError(e)) rethrow;
      print('[DB] $op: transient connection error — $e; '
          'reopening and retrying once');
      await reopen();
      return await action();
    }
  }

  /// Establishes (or re-establishes) the MongoDB connection.
  ///
  /// Lock pattern: concurrent callers share a single in-flight handshake
  /// via [_connectFuture]. Without this, the boot-time `main()` connect
  /// and an early screen mount (e.g. IssueConsole's `fetchReports`) would
  /// each drive their own `_db.open()` on the same Db instance and one of
  /// them would return while the state machine was still `OPENING`.
  ///
  /// Detailed exception logging (type + stack) lives in [_performConnect];
  /// this outer method only owns the lock lifecycle.
  Future<void> connect() async {
    if (_isOpen) return;

    // Capture into a local so the non-null check type-promotes cleanly.
    // Instance fields don't promote in Dart, so `return _connectFuture;`
    // would otherwise be a `Future<void>?` → `Future<void>` mismatch.
    final inFlight = _connectFuture;
    if (inFlight != null) return inFlight;

    // Stash a local reference to the attempt as well, so our await targets
    // a known non-null Future even if a concurrent caller's catch block
    // nulls `_connectFuture` before our await resumes.
    final attempt = _performConnect();
    _connectFuture = attempt;
    try {
      await attempt;
    } catch (_) {
      // Clear the lock so the next caller starts a fresh attempt instead
      // of awaiting a permanently-failed future. Use `identical` so we
      // don't accidentally clobber a *new* future started by a teardown
      // path (reopen / _resetForReconnect) that ran while we were awaiting.
      if (identical(_connectFuture, attempt)) _connectFuture = null;
      rethrow;
    }
  }

  /// Inner handshake — only ever invoked by [connect] under the lock.
  /// Logs the EXACT underlying exception (SocketException, authentication
  /// failure, DNS error, etc.) with a stack trace, then tears down any
  /// half-constructed `_db` so the next attempt starts from a clean slate.
  Future<void> _performConnect() async {
    try {
      _db = await Db.create(AppConfig.mongoUri);
      await _db!.open();
      _reports = _db!.collection(AppConfig.reportsCollection);
      print('[DB] Connected — database: "${_db!.databaseName}", '
          'collection: "${_reports!.collectionName}", state: ${_db!.state}');
    } catch (e, st) {
      print('[DB] connect() FAILED — ${e.runtimeType}: $e');
      print('[DB] stack trace:\n$st');
      try {
        await _db?.close();
      } catch (_) {}
      _db = null;
      _reports = null;
      _users = null;
      rethrow;
    }
  }

  Future<void> close() async {
    if (_db != null && _isOpen) {
      await _db!.close();
    }
    _db = null;
    _reports = null;
    _users = null;
    _connectFuture = null;
  }

  Future<DbCollection> _collection() async {
    await _ensureConnected();
    return _reports!;
  }

  Future<DbCollection> _usersCollection() async {
    await _ensureConnected();
    _users ??= _db!.collection(AppConfig.usersCollection);
    return _users!;
  }

  /// Ensures the Mongo socket is alive before issuing any operation.
  ///
  /// Routes through [connect] (and its lock) so we never call `_db!.open()`
  /// directly here — a direct call would race against an in-flight handshake
  /// driven by `main()` or another caller, which is exactly what produced
  /// the `State.OPENING` error at startup. On a hard failure we fall back
  /// to [reopen], which forces a clean teardown + fresh handshake.
  Future<void> _ensureConnected() async {
    if (_isOpen && _reports != null) return;
    try {
      await connect();
    } catch (_) {
      await reopen();
    }
  }

  /// Pulls the EXP value from the `users` collection for [username]. If the
  /// document doesn't exist yet, seeds it with [defaultExp] so subsequent
  /// logins read a consistent, Mongo-backed value. Falls back to
  /// [defaultExp] if the database is unreachable so login still succeeds
  /// offline.
  Future<int> fetchOrSeedUserExp(String username, int defaultExp) async {
    try {
      return await _withReconnectRetry('fetchOrSeedUserExp', () async {
        final col = await _usersCollection();
        final doc = await col.findOne(where.eq('username', username));
        if (doc != null) {
          final raw = doc['currentExp'];
          if (raw is num) return raw.toInt();
          // Document present but malformed — repair it.
          await col.updateOne(
            where.eq('username', username),
            modify.set('currentExp', defaultExp),
          );
          return defaultExp;
        }
        await col.insertOne({
          'username': username,
          'currentExp': defaultExp,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        });
        return defaultExp;
      });
    } catch (e) {
      return defaultExp;
    }
  }

  /// Atomically increments [username]'s `currentExp` by [delta] in the
  /// users collection and returns the new total. Used by the EXP
  /// gamification hooks (+50 per report submitted, +250 per task that
  /// transitions to resolved). Seeds the user document at [delta] if it
  /// doesn't exist yet so brand-new accounts don't silently lose the
  /// reward.
  ///
  /// Returns the **post-increment** value, or null if the database is
  /// unreachable so callers can fall back to the cached in-memory value.
  /// Wrapped in [_withReconnectRetry] for the same cold-boot resilience
  /// as the other write paths.
  Future<int?> awardExp({
    required String username,
    required int delta,
  }) async {
    if (delta == 0) return null;
    if (username.trim().isEmpty) {
      print('[DB] awardExp: refusing to write — empty username');
      return null;
    }

    try {
      return await _withReconnectRetry('awardExp', () async {
        final col = await _usersCollection();

        // Raw update document rather than ModifierBuilder. Two reasons:
        //   1. Skips any subtle conversion bugs in the chained builder
        //      when mixing `$inc` and `$setOnInsert` in one call.
        //   2. Drops `$setOnInsert.username` — the selector already pins
        //      the new doc's `username` on upsert, so writing it twice
        //      is redundant and on some server configs raises a path
        //      conflict.
        //
        // Schema this matches: { username: String, currentExp: Int,
        // createdAt: ISO-8601 String } — same shape used by
        // fetchOrSeedUserExp and the resident/admin seed paths.
        final selector = <String, dynamic>{'username': username};
        final update = <String, dynamic>{
          r'$inc': <String, dynamic>{'currentExp': delta},
          r'$setOnInsert': <String, dynamic>{
            'createdAt': DateTime.now().toUtc().toIso8601String(),
          },
        };

        print('[DB] awardExp → $username += $delta');
        final result = await col.updateOne(
          selector,
          update,
          upsert: true,
        );
        print('[DB] awardExp result — success: ${result.isSuccess}, '
            'matched: ${result.nMatched}, '
            'modified: ${result.nModified}, '
            'upserted: ${result.nUpserted}');

        if (!result.isSuccess) {
          print('[DB] awardExp: write was not acknowledged successfully');
          return null;
        }

        // Re-read the doc so callers get the authoritative post-increment
        // value — mongo_dart's WriteResult does NOT surface the new field
        // value for an $inc update.
        final doc = await col.findOne(selector);
        final raw = doc?['currentExp'];
        final newTotal = raw is num ? raw.toInt() : null;
        print('[DB] awardExp → $username new currentExp = $newTotal');
        return newTotal;
      });
    } catch (e, st) {
      print('[DB] awardExp($username, +$delta) FAILED — $e');
      print('[DB] awardExp stack:\n$st');
      return null;
    }
  }

  /// Persists a new report.
  ///
  /// Returns `true` on success, `false` on any connection or write failure.
  /// Performs a pre-flight check on the Mongo connection state — if the
  /// socket dropped while the user was on the camera/preview screen, this
  /// re-opens it before issuing the insert, eliminating the "No master
  /// connection" error that surfaces after long idle periods.
  Future<bool> saveReport(ReportModel report) async {
    try {
      // Pre-flight: ensure the Mongo connection is OPEN before insertOne.
      // Always route through connect() so we share the lock with any
      // in-flight handshake — never call _db!.open() directly here.
      if (!_isOpen) {
        print('[DB] Pre-flight: connection not OPEN — re-establishing…');
        await connect();
      }

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

      // Wrap the actual insert in the retry helper so a transient socket
      // reset between pre-flight and write doesn't lose the submission.
      // Re-grab `_reports` inside the closure so a `reopen()` between
      // attempts doesn't leave us holding a handle to the closed Db.
      final result = await _withReconnectRetry(
        'saveReport.insertOne',
        () async => _reports!.insertOne(payload),
      );
      print(
          '[DB] insertOne — success: ${result.isSuccess}, nInserted: ${result.nInserted}, id: $id');

      if (!result.isSuccess || result.nInserted == 0) {
        print(
            '[DB] saveReport error: insert rejected — ${result.writeError?.errmsg ?? "nInserted=0"}');
        return false;
      }
      return true;
    } catch (e) {
      print('[DB] saveReport error: $e');
      return false;
    }
  }

  /// Forces a fresh connection. Used by the UI as a recovery step before
  /// retrying a failed submission. Clears [_connectFuture] so the
  /// subsequent `connect()` actually re-runs the handshake instead of
  /// short-circuiting on a stale completed future.
  Future<void> reopen() async {
    try {
      if (_db != null && _isOpen) await _db!.close();
    } catch (_) {}
    _db = null;
    _reports = null;
    _connectFuture = null;
    await connect();
  }

  // Last successful report fetch — shared across polling cycles so a
  // transient error doesn't blank the UI, and so a freshly mounted home
  // screen has something to render before the first network round-trip.
  List<ReportModel> _cachedReports = const [];

  /// Public read of the most recent successful fetch. Useful for screens
  /// that want a synchronous starting point before their stream emits.
  List<ReportModel> get cachedReports => _cachedReports;

  /// Emits the full report list, then re-fetches every [interval].
  ///
  /// Lifecycle per loop iteration:
  ///   1. **Connection gate** — verify `_isOpen` BEFORE issuing any read.
  ///      If the socket is down, call [reopen] (a clean close → recreate →
  ///      open cycle). On reconnect failure, yield the cached list and
  ///      back off for [reconnectBackoff] instead of slamming the same
  ///      dead socket every [interval] tick (which is what produced the
  ///      infinite "No master connection" flood at startup).
  ///   2. **Fetch** — pull reports. On success, yield fresh data. On a
  ///      connection-shaped error, tear down `_db` so the next iteration's
  ///      gate triggers a real reconnect (not just another doomed fetch
  ///      against a zombie socket), then back off.
  ///
  /// Synchronous first yield (before the loop) keeps `StreamBuilder.hasData`
  /// true so the map shell renders immediately — empty on cold start,
  /// populated on remount/return-from-camera.
  Stream<List<ReportModel>> watchReports({
    Duration interval = const Duration(seconds: 3),
    Duration reconnectBackoff = const Duration(seconds: 5),
  }) async* {
    print('[DB] watchReports: subscribed — yielding cache '
        '(${_cachedReports.length} reports), '
        'initial DB state: ${_db?.state}');
    yield _cachedReports;

    while (true) {
      // ── 1. Connection gate ──────────────────────────────────────────
      if (!_isOpen) {
        print('[DB] watchReports: DB not open (state: ${_db?.state}) — '
            'attempting reconnect…');
        try {
          await reopen();
          print('[DB] watchReports: reconnect SUCCESS — '
              'state: ${_db?.state}');
        } catch (e) {
          print('[DB] watchReports: reconnect FAILED — $e '
              '(yielding ${_cachedReports.length} cached, '
              'retrying in ${reconnectBackoff.inSeconds}s)');
          yield _cachedReports;
          await Future.delayed(reconnectBackoff);
          continue;
        }
      }

      // ── 2. Fetch ────────────────────────────────────────────────────
      try {
        final fresh = await fetchReports();
        _cachedReports = fresh;
        yield fresh;
      } catch (e) {
        print('[DB] watchReports: fetch error — $e '
            '(yielding ${_cachedReports.length} cached, '
            'will reconnect in ${reconnectBackoff.inSeconds}s)');
        yield _cachedReports;
        // The socket is suspect — drop it so the next iteration's gate
        // forces a full reopen instead of fetching against a dead Db.
        await _resetForReconnect();
        await Future.delayed(reconnectBackoff);
        continue;
      }

      await Future.delayed(interval);
    }
  }

  /// Tears down `_db` so the next operation forces a clean reconnect.
  /// Swallows close errors — the socket is already broken; we only care
  /// about clearing the local handles. Nulls [_connectFuture] so the next
  /// `connect()` re-runs the handshake instead of returning the stale
  /// completed future from the now-dead session.
  Future<void> _resetForReconnect() async {
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
    _reports = null;
    _users = null;
    _connectFuture = null;
  }

  /// Fetches all reports, newest first. Updates the in-memory cache so the
  /// stream's next yield (and any newly mounted home screen) has fresh data
  /// without waiting on the poll interval.
  ///
  /// Wrapped in [_withReconnectRetry] so a transient cold-boot socket reset
  /// from Atlas self-heals (reopen + one retry) before the error reaches
  /// callers that lack their own retry loop (e.g. `IssueConsoleScreen._load`).
  Future<List<ReportModel>> fetchReports({bool onlyPending = false}) {
    return _withReconnectRetry('fetchReports', () async {
      final col = await _collection();
      final selector = where.sortBy('createdAt', descending: true);
      if (onlyPending) {
        selector.eq('status', ReportStatus.open.wire);
      }
      final docs = await col.find(selector).toList();
      final reports = docs.map((d) => ReportModel.fromMap(d)).toList();
      if (!onlyPending) _cachedReports = reports;
      return reports;
    });
  }

  /// Fetches a single report by id. Returns null when the document doesn't
  /// exist. Used by the verification pipeline operations that need to
  /// re-read the *current* server-side state of a report (severity,
  /// assignee, proof URL) before applying a transition — never trust the
  /// snapshot the UI was last rendered with.
  Future<ReportModel?> fetchReportById(ObjectId id) {
    return _withReconnectRetry('fetchReportById', () async {
      final col = await _collection();
      final doc = await col.findOne(where.id(id));
      if (doc == null) return null;
      return ReportModel.fromMap(doc);
    });
  }

  /// Updates a report's status. Stamps `fixedAt` when status becomes
  /// `resolved`. Wrapped in [_withReconnectRetry] for the same reason as
  /// [fetchReports].
  ///
  /// This is a low-level setter that the verification pipeline methods
  /// below build on — direct callers should prefer the role-aware methods
  /// ([volunteerForReport], [submitProofOfWork], [adminVerifyAndResolve])
  /// so the spec'd rules are enforced.
  Future<bool> updateReportStatus(ObjectId id, ReportStatus status) {
    return _withReconnectRetry('updateReportStatus', () async {
      final col = await _collection();
      final update = modify.set('status', status.wire);
      if (status == ReportStatus.resolved) {
        update.set('fixedAt', DateTime.now().toUtc().toIso8601String());
      } else {
        update.unset('fixedAt');
      }
      final result = await col.updateOne(where.id(id), update);
      return result.isSuccess && (result.nModified > 0 || result.nMatched > 0);
    });
  }

  // ───────────────────────────────────────────────────────────────────────
  // Verification pipeline (Rules A + B)
  //
  // The methods below are the ONLY blessed transitions for the open →
  // in_progress → pending_verification → resolved lifecycle. They all
  // re-read the report from Mongo before mutating so the server-side
  // severity / status / proof URL is the source of truth, not whatever
  // stale copy the UI held when the user tapped.
  // ───────────────────────────────────────────────────────────────────────

  /// Rule A — Admin Volunteer Restriction.
  ///
  /// Assigns [user] as the volunteer for the report identified by [id] and
  /// transitions its status to `in_progress`. If [user] has the admin role
  /// AND the report's `severity > 3`, the assignment is blocked with a
  /// [VerificationRuleException] carrying the spec'd error string —
  /// "Admins are restricted from volunteering for high-severity tasks
  /// (above Priority 3)." No write occurs in that case.
  ///
  /// Also refuses to overwrite an already-assigned task (idempotent guard).
  Future<ReportModel> volunteerForReport({
    required ObjectId id,
    required AppUser user,
  }) async {
    final report = await fetchReportById(id);
    if (report == null) {
      throw const DatabaseException('Report not found.');
    }

    if (user.isCityAdmin && report.severity > kAdminVolunteerSeverityCap) {
      throw const VerificationRuleException(
        'Admins are restricted from volunteering for high-severity tasks '
        '(above Priority 3).',
      );
    }

    if (report.status != ReportStatus.open &&
        report.status != ReportStatus.inProgress) {
      throw VerificationRuleException(
        'This task is "${report.status.label}" and cannot be re-volunteered.',
      );
    }
    if (report.assignedVolunteerId != null &&
        report.assignedVolunteerId != user.username &&
        report.status == ReportStatus.inProgress) {
      throw const VerificationRuleException(
        'This task is already assigned to another volunteer.',
      );
    }

    return _withReconnectRetry('volunteerForReport', () async {
      final col = await _collection();
      final update = modify
          .set('status', ReportStatus.inProgress.wire)
          .set('assignedVolunteerId', user.username);
      final result = await col.updateOne(where.id(id), update);
      if (!result.isSuccess ||
          (result.nMatched == 0 && result.nModified == 0)) {
        throw const DatabaseException('Failed to assign volunteer.');
      }
      return report.copyWith(
        status: ReportStatus.inProgress,
        assignedVolunteerId: user.username,
      );
    });
  }

  /// Rule B (first half) — Volunteer Submits Proof.
  ///
  /// Saves [proofImageUrl] to the report and flips status to
  /// `pending_verification`. Refuses the call when:
  ///   • the report isn't currently `in_progress` (you can't submit proof
  ///     for something that hasn't been started),
  ///   • [submittingUser] isn't the assigned volunteer (admins included —
  ///     an admin who wants to fast-track must volunteer first), or
  ///   • [proofImageUrl] is empty / null.
  Future<ReportModel> submitProofOfWork({
    required ObjectId id,
    required AppUser submittingUser,
    required String proofImageUrl,
  }) async {
    if (proofImageUrl.trim().isEmpty) {
      throw const VerificationRuleException(
        'A proof-of-work image is required before submitting for verification.',
      );
    }

    final report = await fetchReportById(id);
    if (report == null) {
      throw const DatabaseException('Report not found.');
    }

    if (report.status != ReportStatus.inProgress) {
      throw VerificationRuleException(
        'Only tasks that are "In Progress" can submit proof — this one is '
        '"${report.status.label}".',
      );
    }
    if (report.assignedVolunteerId == null ||
        report.assignedVolunteerId != submittingUser.username) {
      throw const VerificationRuleException(
        'Only the assigned volunteer can submit completion proof for this task.',
      );
    }

    return _withReconnectRetry('submitProofOfWork', () async {
      final col = await _collection();
      final update = modify
          .set('status', ReportStatus.pendingVerification.wire)
          .set('proofOfWorkImageUrl', proofImageUrl);
      final result = await col.updateOne(where.id(id), update);
      if (!result.isSuccess ||
          (result.nMatched == 0 && result.nModified == 0)) {
        throw const DatabaseException('Failed to record proof of work.');
      }
      return report.copyWith(
        status: ReportStatus.pendingVerification,
        proofOfWorkImageUrl: proofImageUrl,
      );
    });
  }

  /// Rule B (second half) — Admin Verifies & Resolves.
  ///
  /// Only callable by an admin, only when the report is in
  /// `pending_verification`, and only when `proofOfWorkImageUrl` is
  /// populated (i.e. the admin had something to actually inspect). Stamps
  /// `fixedAt` for the resolved-time ledger.
  Future<ReportModel> adminVerifyAndResolve({
    required ObjectId id,
    required AppUser admin,
  }) async {
    if (!admin.isCityAdmin) {
      throw const VerificationRuleException(
        'Only admins can verify and resolve a task.',
      );
    }

    final report = await fetchReportById(id);
    if (report == null) {
      throw const DatabaseException('Report not found.');
    }

    if (report.status != ReportStatus.pendingVerification) {
      throw VerificationRuleException(
        'Only tasks in "Pending Verification" can be resolved — this one is '
        '"${report.status.label}".',
      );
    }
    final proof = report.proofOfWorkImageUrl;
    if (proof == null || proof.isEmpty) {
      throw const VerificationRuleException(
        'Cannot resolve: the volunteer has not uploaded a proof-of-work image yet.',
      );
    }

    final resolved = await _withReconnectRetry('adminVerifyAndResolve',
        () async {
      final col = await _collection();
      final update = modify
          .set('status', ReportStatus.resolved.wire)
          .set('fixedAt', DateTime.now().toUtc().toIso8601String());
      final result = await col.updateOne(where.id(id), update);
      if (!result.isSuccess ||
          (result.nMatched == 0 && result.nModified == 0)) {
        throw const DatabaseException('Failed to mark task resolved.');
      }
      return report.copyWith(
        status: ReportStatus.resolved,
        fixedAt: DateTime.now().toUtc(),
      );
    });

    // EXP reward: +250 EXP to the volunteer whose work was just verified.
    // Best-effort — a failure to increment shouldn't roll back the
    // resolution; the next login / home refresh will catch any drift
    // because awardExp re-reads the doc and fetchOrSeedUserExp converges
    // on the persisted value.
    final volunteer = resolved.assignedVolunteerId;
    if (volunteer != null && volunteer.isNotEmpty) {
      await awardExp(username: volunteer, delta: kExpRewardResolve);
    }

    return resolved;
  }
}

/// EXP awarded to the resident who submits a new report. Spec value: +50.
const int kExpRewardReportSubmitted = 50;

/// EXP awarded to the volunteer when a task they handled transitions to
/// `resolved` (i.e. admin verified their proof of work). Spec value: +250.
const int kExpRewardResolve = 250;
