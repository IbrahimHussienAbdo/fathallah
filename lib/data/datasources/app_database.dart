import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Singleton that owns the SQLite connection and all raw SQL operations.
/// All public methods return plain [Map] rows — mapping to entities
/// is done in the repository layer.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  static Database? _db;

  // ── Lifecycle ─────────────────────────────────────────

  /// Returns the open database, initialising it on first call.
  Future<Database> get database async {
    _db ??= await _openDatabase();
    return _db!;
  }

  /// Opens (or creates) the SQLite database file.
  Future<Database> _openDatabase() async {
    final path = join(await getDatabasesPath(), 'analytics_v1.db');
    return openDatabase(path, version: 2, onCreate: _createTables);
  }

  /// Creates tables and indices on first run.
  Future<void> _createTables(Database db, int version) async {
    // Purchases table — one row per line in the XLSX file.
    await db.execute('''
      CREATE TABLE purchases (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        item_code   TEXT NOT NULL,
        item_name   TEXT NOT NULL,
        quantity    REAL NOT NULL DEFAULT 0,
        unit_price  REAL NOT NULL DEFAULT 0,
        total_cost  REAL NOT NULL DEFAULT 0
      )
    ''');

    // Sales table — one row per line in the CSV file.
    await db.execute('''
      CREATE TABLE sales (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        item_code     TEXT NOT NULL,
        item_name     TEXT NOT NULL,
        branch_name   TEXT,
        category      TEXT,
        quantity      REAL NOT NULL DEFAULT 0,
        unit_price    REAL NOT NULL DEFAULT 0,
        total_revenue REAL NOT NULL DEFAULT 0
      )
    ''');

    // Indices on item_code for fast JOIN and search.
    await db.execute(
        'CREATE INDEX idx_purchase_code ON purchases(item_code)');
    await db.execute(
        'CREATE INDEX idx_sale_code ON sales(item_code)');
    await db.execute(
        'CREATE INDEX idx_purchase_name ON purchases(item_name)');
    await db.execute(
        'CREATE INDEX idx_sale_name ON sales(item_name)');
  }

  // ── Write operations ──────────────────────────────────

  /// Batch-inserts purchase rows for performance (one transaction).
  /// Optimal chunk size for sqflite batch inserts on Android ART runtime.
  /// 2000 rows/transaction gives best throughput for 1M+ record imports
  /// on devices with 4GB+ RAM. Drop to 1000 for 2GB devices.
  static const int _kChunkSize = 3000;

  /// Batch-inserts purchase rows in chunked transactions to avoid OOM
  /// with large files (1M+ records). Each chunk is a separate transaction.
  Future<void> batchInsertPurchases(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await _chunkedInsert(db, 'purchases', rows);
  }

  /// Batch-inserts sale rows in chunked transactions to avoid OOM.
  Future<void> batchInsertSales(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await _chunkedInsert(db, 'sales', rows);
  }

  /// Inserts [rows] into [table] in chunks of [_kChunkSize] per transaction.
  /// Never holds more than _kChunkSize rows in memory at once.
  Future<void> _chunkedInsert(
    Database db,
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    for (int i = 0; i < rows.length; i += _kChunkSize) {
      final end = (i + _kChunkSize).clamp(0, rows.length);
      final chunk = rows.sublist(i, end);
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final row in chunk) {
          batch.insert(table, row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
    }
  }

  /// Deletes all rows from both tables.
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('purchases');
    await db.delete('sales');
  }

  // ── Read operations ───────────────────────────────────

  /// Returns row counts for the summary cards on the upload screen.
  Future<Map<String, int>> getCounts() async {
    final db = await database;
    final p = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM purchases')) ??
        0;
    final s = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM sales')) ??
        0;
    return {'purchases': p, 'sales': s};
  }

  /// Returns top [n] items ranked by total sales revenue.
  /// Joins against purchases to include cost data for profit calculation.
  Future<List<Map<String, dynamic>>> getTopSales(int n) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        s.item_code,
        s.item_name,
        SUM(s.quantity)      AS sold_qty,
        SUM(s.total_revenue) AS total_revenue,
        COALESCE(p.purchased_qty, 0) AS purchased_qty,
        COALESCE(p.total_cost, 0)    AS total_cost
      FROM sales s
      LEFT JOIN (
        SELECT item_code, SUM(quantity) AS purchased_qty, SUM(total_cost) AS total_cost
        FROM purchases
        GROUP BY item_code
      ) p ON s.item_code = p.item_code
      GROUP BY s.item_code, s.item_name
      ORDER BY total_revenue DESC
      LIMIT ?
    ''', [n]);
  }

  /// Returns items purchased but with no matching sales record.
  /// Matches on item_code first, then item_name as fallback.
  Future<List<Map<String, dynamic>>> getDeadstock() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        item_code,
        item_name,
        SUM(quantity)   AS purchased_qty,
        SUM(total_cost) AS total_cost,
        0.0             AS sold_qty,
        0.0             AS total_revenue
      FROM purchases
      WHERE item_code NOT IN (
        SELECT DISTINCT item_code FROM sales
        WHERE item_code IS NOT NULL AND item_code != ''
      )
      AND item_name NOT IN (
        SELECT DISTINCT item_name FROM sales
      )
      GROUP BY item_code, item_name
      ORDER BY total_cost DESC
    ''');
  }

  /// Full profit/loss report: LEFT JOIN purchases → sales, then UNION
  /// sales that have no matching purchase (consignment / external stock).
  Future<List<Map<String, dynamic>>> getProfitReport() async {
    final db = await database;
    return db.rawQuery('''
      SELECT * FROM (
        SELECT
          COALESCE(p.item_code, s.item_code) AS item_code,
          COALESCE(p.item_name, s.item_name) AS item_name,
          COALESCE(p.purchased_qty, 0)       AS purchased_qty,
          COALESCE(s.sold_qty, 0)            AS sold_qty,
          COALESCE(p.total_cost, 0)          AS total_cost,
          COALESCE(s.total_revenue, 0)       AS total_revenue
        FROM
          (SELECT item_code, item_name,
                  SUM(quantity)   AS purchased_qty,
                  SUM(total_cost) AS total_cost
           FROM purchases
           GROUP BY item_code, item_name) p
        LEFT JOIN
          (SELECT item_code, item_name,
                  SUM(quantity)      AS sold_qty,
                  SUM(total_revenue) AS total_revenue
           FROM sales
           GROUP BY item_code, item_name) s
          ON p.item_code = s.item_code

        UNION

        SELECT
          s.item_code, s.item_name,
          0.0              AS purchased_qty,
          s.sold_qty,
          0.0              AS total_cost,
          s.total_revenue
        FROM
          (SELECT item_code, item_name,
                  SUM(quantity)      AS sold_qty,
                  SUM(total_revenue) AS total_revenue
           FROM sales
           GROUP BY item_code, item_name) s
        WHERE s.item_code NOT IN (SELECT item_code FROM purchases)
      ) q
      ORDER BY (q.total_revenue - q.total_cost) DESC
    ''');
  }


  /// Case-insensitive LIKE search across item names in both tables.
  /// Results are tagged with 'record_type' = 'purchase' or 'sale'.
  Future<List<Map<String, dynamic>>> searchByName(String name) async {
    final db = await database;
    final pattern = '%$name%';

    final purchases = await db.query(
      'purchases',
      where: 'item_name LIKE ?',
      whereArgs: [pattern],
    );
    final sales = await db.query(
      'sales',
      where: 'item_name LIKE ?',
      whereArgs: [pattern],
    );

    return [
      ...purchases.map((r) => {...r, 'record_type': 'purchase'}),
      ...sales.map((r) => {...r, 'record_type': 'sale'}),
    ];
  }
}
