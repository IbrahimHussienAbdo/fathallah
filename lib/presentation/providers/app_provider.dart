import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/datasources/app_database.dart';
import '../../data/datasources/file_parser.dart';
import '../../data/repositories/item_repository_impl.dart';
import '../../domain/entities/item.dart';
import '../../domain/usecases/item_usecases.dart';

// ── Top-level isolate helpers ──────────────────────────────────────────────
// Must be top-level (not methods) for compute() to spawn them in an isolate.

/// Parses purchases XLSX bytes and returns DB-ready maps in one isolate call.
/// Combining parse + map avoids sending a large List<PurchaseItem> across
/// the isolate boundary (serialisation overhead on 1M rows is significant).
List<Map<String, dynamic>> _parsePurchasesXlsxToMaps(List<int> bytes) {
  final items = FileParser.parsePurchasesXlsx(bytes);
  return items.map((e) => {
    'item_code':  e.itemCode,
    'item_name':  e.itemName,
    'quantity':   e.quantity,
    'unit_price': e.unitPrice,
    'total_cost': e.totalCost,
  }).toList();
}

/// Parses sales CSV bytes and returns DB-ready maps in one isolate call.
List<Map<String, dynamic>> _parseSalesCsvToMaps(List<int> bytes) {
  final items = FileParser.parseSalesCsv(bytes);
  return items.map((e) => {
    'item_code':     e.itemCode,
    'item_name':     e.itemName,
    'branch_name':   e.branchName,
    'category':      e.category,
    'quantity':      e.quantity,
    'unit_price':    e.unitPrice,
    'total_revenue': e.totalRevenue,
  }).toList();
}
const int _kMinFreeStorageBytes = 50 * 1024 * 1024;

/// Central [ChangeNotifier] that holds all app state and orchestrates
/// use-case calls. Screens consume this via [Provider.of] / [Consumer].
class AppProvider extends ChangeNotifier {
  // ── Wiring ────────────────────────────────────────────

  final _repo = ItemRepositoryImpl();

  late final _topSalesUC  = GetTopSalesUseCase(_repo);
  late final _deadstockUC = GetDeadstockUseCase(_repo);
  late final _profitUC    = GetProfitReportUseCase(_repo);
  late final _searchUC    = SearchItemsUseCase(_repo);

  // ── Upload state ──────────────────────────────────────
  bool   isLoading     = false;
  String statusMessage = '';
  bool   statusIsError = false;
  Map<String, int> counts = {'purchases': 0, 'sales': 0};

  // ── Storage warning state (consumed once by the UI) ───
  bool lowStorageDetected = false;

  // ── Analytics state ───────────────────────────────────
  List<ItemAnalysis> topSales     = [];
  List<ItemAnalysis> deadstock    = [];
  List<ItemAnalysis> profitReport = [];
  bool               analyticsLoaded = false;

  // ── Search state ──────────────────────────────────────
  List<Map<String, dynamic>> searchResults = [];
  bool searchLoading = false;
  bool hasSearched   = false;

  // ── Derived totals ────────────────────────────────────

  /// Total revenue from all sales.
  double get totalRevenue =>
      profitReport.fold(0, (s, e) => s + e.totalRevenue);

  /// Total cost from all purchases.
  double get totalCost =>
      profitReport.fold(0, (s, e) => s + e.totalCost);

  /// Net profit across all items.
  double get totalProfit => totalRevenue - totalCost;

  /// Number of deadstock items.
  int get deadstockCount => deadstock.length;

  // ── Init ──────────────────────────────────────────────

  AppProvider() {
    _refreshCounts();
  }

  // ── Upload (bytes-based — for small files only) ───────

  /// Parses and stores a purchases XLSX file from raw bytes.
  /// For large files (>50MB) use [uploadPurchasesFromPath] instead.
  Future<void> uploadPurchases(List<int> bytes, String filename) async {
    if (!await _checkStorage()) return;
    _setLoading(true, 'File Uploading...');
    try {
      _setLoading(true, 'File Uploaded Successfully.');
      await Future.delayed(const Duration(seconds: 1));
      _setLoading(true, 'Processing Data...');
      final items = await compute(FileParser.parsePurchasesXlsx, bytes);
      if (items.isEmpty) throw Exception('No valid data rows found in file.');
      _setLoading(true, 'Analytics in Progress...');
      await _repo.insertPurchases(items);
      analyticsLoaded = false;
      await _refreshCounts();
      _succeed('Analytics Completed.  ✅  ${items.length} purchase records imported.');
    } catch (e) {
      _fail('$e');
    }
  }

  /// Parses and stores a sales CSV file from raw bytes.
  /// For large files (>50MB) use [uploadSalesFromPath] instead.
  Future<void> uploadSales(List<int> bytes, String filename) async {
    if (!await _checkStorage()) return;
    _setLoading(true, 'File Uploading...');
    try {
      _setLoading(true, 'File Uploaded Successfully.');
      await Future.delayed(const Duration(seconds: 1));
      _setLoading(true, 'Processing Data...');
      final safeBytes = List<int>.from(bytes);
      final items = await compute(FileParser.parseSalesCsv, safeBytes);
      if (items.isEmpty) throw Exception('No valid data rows found in file.');
      _setLoading(true, 'Analytics in Progress...');
      await _repo.insertSales(items);
      analyticsLoaded = false;
      await _refreshCounts();
      _succeed('Analytics Completed.  ✅  ${items.length} sale records imported.');
    } catch (e) {
      _fail('$e');
    }
  }

  // ── Upload (path-based — for large files) ─────────────

  /// Uploads a sales CSV file from [filePath] using line-by-line streaming.
  /// Never loads the full file into RAM — inserts 500 rows per transaction.
  Future<void> uploadSalesFromPath(String filePath, String filename) async {
    if (!await _checkStorage()) return;
    _setLoading(true, 'File Uploading...');
    try {
      _setLoading(true, 'File Uploaded Successfully.');
      await Future.delayed(const Duration(seconds: 1));
      _setLoading(true, 'Processing Data...');

      final isXlsx = filename.toLowerCase().endsWith('.xlsx') ||
          filename.toLowerCase().endsWith('.xls');

      if (isXlsx) {
        // NOTE: pre-existing limitation — XLSX sales parser not implemented.
        // Only CSV sales files are supported. Purchases support XLSX.
        throw Exception(
            'Sales XLSX files are not supported. Please use a CSV file.');
      }

      // CSV: stream row-by-row — at most 500 rows ever in RAM at once.
      int totalInserted = 0;
      final db = await AppDatabase.instance.database;

      await for (final chunk in FileParser.streamSalesCsvFromPath(filePath)) {
        if (chunk.isEmpty) continue;

        final rows = chunk.map((e) => {
              'item_code':     e.itemCode,
              'item_name':     e.itemName,
              'branch_name':   e.branchName,
              'category':      e.category,
              'quantity':      e.quantity,
              'unit_price':    e.unitPrice,
              'total_revenue': e.totalRevenue,
            }).toList();

        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final row in rows) {
            batch.insert('sales', row,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });

        totalInserted += chunk.length;
        _setLoading(true, 'Processing Data... ($totalInserted records)');
      }

      if (totalInserted == 0) {
        throw Exception('No valid data rows found in file.');
      }

      analyticsLoaded = false;
      await _refreshCounts();
      _succeed('Analytics Completed.  ✅  $totalInserted sale records imported.');
    } catch (e) {
      _fail('$e');
    }
  }

  /// Uploads a purchases XLSX/XLS/CSV file from [filePath].
  ///
  /// Parsing + row mapping both happen in a background isolate so the UI
  /// never freezes. DB insert uses 2000-row chunked transactions.
  Future<void> uploadPurchasesFromPath(
      String filePath, String filename) async {
    if (!await _checkStorage()) return;
    _setLoading(true, 'File Uploading...');
    try {
      _setLoading(true, 'File Uploaded Successfully.');
      await Future.delayed(const Duration(seconds: 1));
      _setLoading(true, 'Processing Data...');

      // Read bytes then hand off to isolate — isolate does parse + map,
      // so the main isolate never holds both raw bytes AND parsed objects.
      final bytes = await File(filePath).readAsBytes();
      final rows  = await compute(_parsePurchasesXlsxToMaps, bytes);

      if (rows.isEmpty) throw Exception('No valid data rows found in file.');

      _setLoading(true, 'Analytics in Progress...');

      // Chunked insert — 2000 rows per transaction.
      final db = await AppDatabase.instance.database;
      const chunkSize = 2000;
      for (int i = 0; i < rows.length; i += chunkSize) {
        final end   = (i + chunkSize).clamp(0, rows.length);
        final chunk = rows.sublist(i, end);
        await db.transaction((txn) async {
          final batch = txn.batch();
          for (final row in chunk) {
            batch.insert('purchases', row,
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });
      }

      analyticsLoaded = false;
      await _refreshCounts();
      _succeed('Analytics Completed.  ✅  ${rows.length} purchase records imported.');
    } catch (e) {
      _fail('$e');
    }
  }

  // ── Clear ─────────────────────────────────────────────

  /// Clears all purchase and sale data from the database.
  Future<void> clearAll() async {
    await _repo.clearAll();
    counts          = {'purchases': 0, 'sales': 0};
    topSales        = [];
    deadstock       = [];
    profitReport    = [];
    searchResults   = [];
    hasSearched     = false;
    analyticsLoaded = false;
    statusMessage   = '🗑️ All data has been cleared.';
    statusIsError   = false;
    notifyListeners();
  }

  // ── Counts ────────────────────────────────────────────

  /// Reloads record counts from the database.
  Future<void> _refreshCounts() async {
    counts = await _repo.getCounts();
    notifyListeners();
  }

  // ── Analytics ─────────────────────────────────────────

  /// Loads all three analytics datasets in parallel.
  /// No-ops if data is already loaded or if there is no data at all.
  Future<void> loadAnalytics() async {
    if (analyticsLoaded) return;
    if ((counts['purchases'] ?? 0) == 0 && (counts['sales'] ?? 0) == 0) return;

    _setLoading(true, 'Analytics in Progress...');
    try {
      final results = await Future.wait([
        _topSalesUC.call(n: 10),
        _deadstockUC.call(),
        _profitUC.call(),
      ]);
      topSales        = results[0] as List<ItemAnalysis>;
      deadstock       = results[1] as List<ItemAnalysis>;
      profitReport    = results[2] as List<ItemAnalysis>;
      analyticsLoaded = true;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Forces a fresh reload of all analytics data.
  Future<void> forceReloadAnalytics() {
    analyticsLoaded = false;
    return loadAnalytics();
  }

  // ── Search ────────────────────────────────────────────

  /// Runs a name-based search across both tables.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    searchLoading = true;
    hasSearched   = true;
    notifyListeners();
    try {
      searchResults = await _searchUC.call(query.trim());
    } finally {
      searchLoading = false;
      notifyListeners();
    }
  }

  /// Resets search state.
  void clearSearch() {
    searchResults = [];
    hasSearched   = false;
    notifyListeners();
  }

  // ── Storage warning ───────────────────────────────────

  /// Acknowledges the low-storage warning so the UI won't re-show it.
  void acknowledgeLowStorage() {
    lowStorageDetected = false;
    notifyListeners();
  }

  // ── Storage check ─────────────────────────────────────

  /// Returns true if there is sufficient free storage to proceed.
  /// Sets [lowStorageDetected] = true and returns false when space < 50 MB.
  Future<bool> _checkStorage() async {
    try {
      final dir      = await getApplicationDocumentsDirectory();
      final freeBytes = await _getFreeBytes(dir.path);
      if (freeBytes != null && freeBytes < _kMinFreeStorageBytes) {
        lowStorageDetected = true;
        notifyListeners();
        return false;
      }
    } catch (_) {
      // Check failed — allow the operation rather than blocking the user.
    }
    return true;
  }

  /// Returns free bytes on the filesystem via `df -k`.
  /// Returns null on platforms that don't support the command (iOS, etc.).
  Future<int?> _getFreeBytes(String dirPath) async {
    try {
      final result = await Process.run('df', ['-k', dirPath]);
      if (result.exitCode != 0) return null;
      final lines = (result.stdout as String).trim().split('\n');
      if (lines.length < 2) return null;
      final parts = lines.last.trim().split(RegExp(r'\s+'));
      if (parts.length < 4) return null;
      final availableKb = int.tryParse(parts[3]);
      if (availableKb == null) return null;
      return availableKb * 1024;
    } catch (_) {
      return null;
    }
  }

  // ── State helpers ─────────────────────────────────────

  void _setLoading(bool loading, String msg) {
    isLoading     = loading;
    statusMessage = msg;
    statusIsError = false;
    notifyListeners();
  }

  void _succeed(String msg) {
    isLoading     = false;
    statusMessage = msg;
    statusIsError = false;
    notifyListeners();
  }

  void _fail(String msg) {
    isLoading     = false;
    statusMessage = '❌ $msg';
    statusIsError = true;
    notifyListeners();
  }
}
