import '../../domain/entities/item.dart';
import '../../domain/repositories/item_repository.dart';
import '../datasources/app_database.dart';

/// Concrete implementation of [ItemRepository].
///
/// Translates between domain entities and the raw maps used by [AppDatabase].
class ItemRepositoryImpl implements ItemRepository {
  final AppDatabase _db;

  /// Inject the database instance (defaults to the singleton).
  ItemRepositoryImpl([AppDatabase? db]) : _db = db ?? AppDatabase.instance;

  // ── Write ─────────────────────────────────────────────

  /// Converts [PurchaseItem] entities to maps and delegates to the database.
  @override
  Future<void> insertPurchases(List<PurchaseItem> items) =>
      _db.batchInsertPurchases(items
          .map((e) => {
                'item_code':  e.itemCode,
                'item_name':  e.itemName,
                'quantity':   e.quantity,
                'unit_price': e.unitPrice,
                'total_cost': e.totalCost,
              })
          .toList());

  /// Converts [SaleItem] entities to maps and delegates to the database.
  @override
  Future<void> insertSales(List<SaleItem> items) =>
      _db.batchInsertSales(items
          .map((e) => {
                'item_code':     e.itemCode,
                'item_name':     e.itemName,
                'branch_name':   e.branchName,
                'category':      e.category,
                'quantity':      e.quantity,
                'unit_price':    e.unitPrice,
                'total_revenue': e.totalRevenue,
              })
          .toList());

  @override
  Future<void> clearAll() => _db.clearAll();

  @override
  Future<Map<String, int>> getCounts() => _db.getCounts();

  // ── Read ──────────────────────────────────────────────

  /// Fetches top sales rows and maps each to an [ItemAnalysis] entity.
  @override
  Future<List<ItemAnalysis>> getTopItemsBySales(int n) async {
    final rows = await _db.getTopSales(n);
    return rows.map(_rowToAnalysis).toList();
  }

  /// Fetches deadstock rows and maps each to an [ItemAnalysis] entity.
  @override
  Future<List<ItemAnalysis>> getDeadstock() async {
    final rows = await _db.getDeadstock();
    return rows.map(_rowToAnalysis).toList();
  }

  /// Fetches profit report rows and maps each to an [ItemAnalysis] entity.
  @override
  Future<List<ItemAnalysis>> getProfitReport() async {
    final rows = await _db.getProfitReport();
    return rows.map(_rowToAnalysis).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> searchByName(String name) =>
      _db.searchByName(name);

  // ── Helpers ───────────────────────────────────────────

  /// Maps a raw database [Map] row to a typed [ItemAnalysis] entity.
  ItemAnalysis _rowToAnalysis(Map<String, dynamic> row) => ItemAnalysis(
        itemCode:     row['item_code']?.toString() ?? '',
        itemName:     row['item_name']?.toString() ?? '',
        purchasedQty: _toDouble(row['purchased_qty']),
        soldQty:      _toDouble(row['sold_qty']),
        totalCost:    _toDouble(row['total_cost']),
        totalRevenue: _toDouble(row['total_revenue']),
      );

  /// Safely converts a dynamic database value to double.
  double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
}
