/// Headless backup / restore for the Wood CFT local cache (task 14.1).
///
/// [BackupService] serialises the full local dataset to a portable, versioned
/// JSON document and restores it back, implementing design.md -> Transaction
/// Boundaries & Sync "(f) Backup restore" and Requirement 16:
///
///   * **Export (16.1).** Serialises the Catalog (varieties, cross-sections),
///     the stock ledger (stock items + the append-only movement ledger),
///     Receipts (sessions + entries), Invoices (+ invoice lines), prices, the
///     settings/policy singletons, and the durable pending-operation queue.
///     Every row keeps its primary key so identity survives a round-trip. The
///     document carries a [BackupMeta] header: `schema_version` (=
///     [kSchemaVersion]), `app_version`, `exported_at` (UTC), and an integrity
///     `checksum` over the canonical payload.
///
///   * **Restore (16.4, 16.5).** Validates the document's structure, schema
///     version, and checksum BEFORE any write. On mismatch or corruption it
///     throws [BackupValidationException] and performs NO writes
///     (all-or-nothing). The actual import runs inside ONE drift transaction:
///     every table is cleared and re-inserted with its original primary key,
///     so restoring the same backup twice (or over existing data) can never
///     duplicate a stock movement — identity is preserved by the stable ids
///     and the unique `idempotency_key`s (16.5, 21.25).
///
/// This is strictly the data layer: it is headless and testable, operating on
/// the local drift [AppDatabase] as the dataset of record for the offline
/// build (design note: the backup covers the authoritative hosted data plus
/// the local cache; offline we use the local DB). It drives no UI and performs
/// no file IO itself — callers decide how to persist the returned document
/// (share sheet, file, etc.).
library;

import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:wood_cft/data/app_database.dart';

/// The current backup document format version (independent of, and currently
/// aligned with, the DB [kSchemaVersion]). Written into every export and
/// validated on restore.
const int kBackupFormatVersion = 1;

/// Thrown when a backup document fails validation BEFORE any write occurs on
/// restore. When this is thrown the database is guaranteed unchanged
/// (design.md -> Error Handling: validate schema and version first, abort on
/// mismatch/corruption with no partial writes; 16.4).
class BackupValidationException implements Exception {
  /// Creates a validation failure with a human-readable [message].
  const BackupValidationException(this.message);

  /// Why the backup was rejected.
  final String message;

  @override
  String toString() => 'BackupValidationException: $message';
}

/// The parsed [BackupMeta] header of a backup document (design.md -> Data
/// Models -> BackupMeta).
@immutable
class BackupMeta {
  /// Creates a backup header.
  const BackupMeta({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.checksum,
  });

  /// The DB schema version the backup was produced against (= [kSchemaVersion]).
  final int schemaVersion;

  /// The producing application version.
  final String appVersion;

  /// When the backup was exported (UTC).
  final DateTime exportedAt;

  /// Integrity checksum over the canonical payload.
  final String checksum;
}

/// Serialises and restores the full local dataset.
class BackupService {
  /// Creates a backup service over [_db]. [appVersion] is stamped into the
  /// exported [BackupMeta] header.
  BackupService(this._db, {this.appVersion = '1.0.0'});

  final AppDatabase _db;

  /// The application version written into exported backups.
  final String appVersion;

  /// The ordered list of table-name keys used in the `data` section of a
  /// backup document. Parent tables precede their children so a restore that
  /// re-inserts in this order never violates a foreign key.
  static const List<String> _tableOrder = [
    'wood_varieties',
    'cross_sections',
    'stock_items',
    'receipt_sessions',
    'receipt_entries',
    'invoices',
    'invoice_lines',
    'stock_movements',
    'price_rates',
    'draft_orders',
    'draft_order_requests',
    'allocation_lines',
    'business_settings',
    'allocation_policies',
    'tax_policies',
    'loading_policies',
    'pending_operations',
    'backup_metas',
  ];

  /// Exports the full dataset to a portable backup document (16.1).
  ///
  /// The returned map is JSON-encodable and has the shape:
  /// ```json
  /// {
  ///   "meta": { "schema_version": 1, "app_version": "..",
  ///             "exported_at": "..UTC ISO..", "checksum": ".." },
  ///   "data": { "<table>": [ {col: val, ..}, .. ], .. }
  /// }
  /// ```
  /// Every row preserves its primary key so identity survives the round-trip.
  Future<Map<String, dynamic>> exportToMap({DateTime? exportedAt}) async {
    final data = <String, dynamic>{};
    for (final table in _db.allTables) {
      final name = table.actualTableName;
      final rows = await _db.customSelect('SELECT * FROM "$name"').get();
      data[name] = rows.map((r) => _encodeRow(r.data)).toList();
    }

    final exported = (exportedAt ?? DateTime.now()).toUtc();
    final meta = <String, dynamic>{
      'schema_version': kSchemaVersion,
      'app_version': appVersion,
      'exported_at': exported.toIso8601String(),
      // Checksum is computed over the canonical data payload only, so it is
      // stable regardless of the (volatile) exported_at timestamp.
      'checksum': _checksum(data),
    };
    return {'meta': meta, 'data': data};
  }

  /// Exports the full dataset to a JSON string (convenience over
  /// [exportToMap]).
  Future<String> exportToJson({DateTime? exportedAt}) async =>
      jsonEncode(await exportToMap(exportedAt: exportedAt));

  /// Restores a backup document previously produced by [exportToMap].
  ///
  /// Validation (16.4) runs BEFORE any write: the document must be
  /// well-formed, its `schema_version` must equal [kSchemaVersion], and its
  /// recomputed checksum must match. Any failure throws
  /// [BackupValidationException] and the database is left unchanged.
  ///
  /// The import itself runs inside ONE transaction (16.5, 21.25): every table
  /// is cleared and the backup rows are re-inserted preserving their primary
  /// keys. Because identity is preserved, restoring the same backup twice (or
  /// over live data) never duplicates a stock movement — the result is exactly
  /// the backed-up dataset.
  Future<void> restoreFromMap(Map<String, dynamic> document) async {
    final data = _validate(document);

    await _db.transaction(() async {
      // Clear children before parents (reverse insert order) so FK constraints
      // are never violated mid-restore.
      for (final name in _tableOrder.reversed) {
        await _db.customStatement('DELETE FROM "$name"');
      }
      // Re-insert parents before children, preserving primary keys so no
      // stock movement (or any other row) is ever duplicated.
      for (final name in _tableOrder) {
        final rows = (data[name] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        for (final row in rows) {
          await _insertRaw(name, row);
        }
      }
    });
  }

  /// Restores a backup from its JSON-string form (convenience over
  /// [restoreFromMap]).
  Future<void> restoreFromJson(String json) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw BackupValidationException('backup is not valid JSON: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const BackupValidationException(
        'backup root must be a JSON object',
      );
    }
    await restoreFromMap(decoded);
  }

  /// Parses and validates [document], returning the validated `data` section.
  /// Throws [BackupValidationException] on any structural, version, or
  /// integrity problem. Performs NO writes (16.4).
  Map<String, dynamic> _validate(Map<String, dynamic> document) {
    final metaRaw = document['meta'];
    if (metaRaw is! Map<String, dynamic>) {
      throw const BackupValidationException('missing or malformed "meta"');
    }
    final dataRaw = document['data'];
    if (dataRaw is! Map<String, dynamic>) {
      throw const BackupValidationException('missing or malformed "data"');
    }

    final schemaVersion = metaRaw['schema_version'];
    if (schemaVersion is! int) {
      throw const BackupValidationException(
        'meta.schema_version must be an integer',
      );
    }
    if (schemaVersion != kSchemaVersion) {
      throw BackupValidationException(
        'unsupported schema_version $schemaVersion '
        '(this build restores version $kSchemaVersion only)',
      );
    }

    // Every expected table key must be present (structural check), and no
    // unknown table keys may appear.
    for (final name in _tableOrder) {
      if (!dataRaw.containsKey(name)) {
        throw BackupValidationException('data is missing table "$name"');
      }
      if (dataRaw[name] is! List) {
        throw BackupValidationException('data["$name"] must be a list');
      }
    }
    for (final key in dataRaw.keys) {
      if (!_tableOrder.contains(key)) {
        throw BackupValidationException('data has unknown table "$key"');
      }
    }

    // Integrity: the recomputed checksum must match the stored one.
    final storedChecksum = metaRaw['checksum'];
    if (storedChecksum is! String) {
      throw const BackupValidationException('meta.checksum must be a string');
    }
    final recomputed = _checksum(dataRaw);
    if (recomputed != storedChecksum) {
      throw const BackupValidationException(
        'checksum mismatch — the backup is corrupt',
      );
    }

    return dataRaw;
  }

  /// Inserts a single raw [row] into table [name], mapping JSON values back to
  /// the SQLite representation drift expects (bool -> 0/1 handled by SQLite's
  /// dynamic typing; everything else passes through as-is).
  Future<void> _insertRaw(String name, Map<String, dynamic> row) async {
    final columns = row.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final quotedCols = columns.map((c) => '"$c"').join(', ');
    final values = columns.map((c) => _decodeValue(row[c])).toList();
    await _db.customStatement(
      'INSERT INTO "$name" ($quotedCols) VALUES ($placeholders)',
      values,
    );
  }

  /// Encodes a raw drift row value into a JSON-safe value. SQLite values are
  /// already `int`, `double`, `String`, `bool`, `Uint8List`, or `null`; byte
  /// blobs are base64-encoded so they survive JSON.
  Map<String, dynamic> _encodeRow(Map<String, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      if (value is List<int>) {
        out[key] = {r'$blob': base64Encode(value)};
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  /// Decodes a JSON value produced by [_encodeRow] back to the value drift
  /// binds into a statement.
  Object? _decodeValue(Object? value) {
    if (value is Map && value.containsKey(r'$blob')) {
      return base64Decode(value[r'$blob'] as String);
    }
    return value;
  }

  /// A deterministic integrity checksum over the canonical form of [data].
  ///
  /// The payload is canonicalised (table order fixed by [_tableOrder]; within
  /// each row, column keys sorted) then hashed with a 64-bit FNV-1a hash. This
  /// is an integrity/corruption check (not a cryptographic signature) and uses
  /// only `dart:core`, so it adds no dependency.
  String _checksum(Map<String, dynamic> data) {
    final canonical = _canonicalString(data);
    return _fnv1a64(canonical);
  }

  /// Produces a stable canonical string for [data] with sorted keys and a
  /// fixed table order, independent of insertion order.
  String _canonicalString(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    for (final name in _tableOrder) {
      buffer
        ..write(name)
        ..write(':');
      final rows = (data[name] as List<dynamic>? ?? const [])
          .cast<Object?>();
      for (final row in rows) {
        buffer.write(_canonicalValue(row));
        buffer.write(';');
      }
      buffer.write('|');
    }
    return buffer.toString();
  }

  /// Canonicalises an arbitrary JSON value: maps have their keys sorted so the
  /// string form is independent of key order.
  String _canonicalValue(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final sb = StringBuffer('{');
      for (final k in keys) {
        sb
          ..write(k)
          ..write('=')
          ..write(_canonicalValue(value[k]))
          ..write(',');
      }
      return (sb..write('}')).toString();
    }
    if (value is List) {
      final sb = StringBuffer('[');
      for (final e in value) {
        sb
          ..write(_canonicalValue(e))
          ..write(',');
      }
      return (sb..write(']')).toString();
    }
    return '$value';
  }

  /// 64-bit FNV-1a hash of [input], returned as a zero-padded hex string.
  String _fnv1a64(String input) {
    // 64-bit FNV offset basis and prime, computed with BigInt to stay exact on
    // the web (JS) target where ints are not 64-bit.
    final mask = (BigInt.one << 64) - BigInt.one;
    var hash = BigInt.parse('14695981039346656037');
    final prime = BigInt.parse('1099511628211');
    for (final unit in utf8.encode(input)) {
      hash = (hash ^ BigInt.from(unit)) & mask;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  /// Parses the [BackupMeta] header from a document without restoring it.
  /// Useful for previewing a backup's provenance. Throws
  /// [BackupValidationException] if the header is malformed.
  static BackupMeta readMeta(Map<String, dynamic> document) {
    final metaRaw = document['meta'];
    if (metaRaw is! Map<String, dynamic>) {
      throw const BackupValidationException('missing or malformed "meta"');
    }
    final schemaVersion = metaRaw['schema_version'];
    final appVersion = metaRaw['app_version'];
    final exportedAt = metaRaw['exported_at'];
    final checksum = metaRaw['checksum'];
    if (schemaVersion is! int ||
        appVersion is! String ||
        exportedAt is! String ||
        checksum is! String) {
      throw const BackupValidationException('malformed backup meta fields');
    }
    final parsedDate = DateTime.tryParse(exportedAt);
    if (parsedDate == null) {
      throw const BackupValidationException(
        'meta.exported_at is not a valid timestamp',
      );
    }
    return BackupMeta(
      schemaVersion: schemaVersion,
      appVersion: appVersion,
      exportedAt: parsedDate.toUtc(),
      checksum: checksum,
    );
  }
}
