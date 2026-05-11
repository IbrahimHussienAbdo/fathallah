import '../entities/item.dart';

/// Abstract contract for data operations.
/// The presentation layer depends only on this interface — never on the implementation.
abstract class ItemRepository {
  /// Bulk-insert purchase records into the database.
  Future<void> insertPurchases(List<PurchaseItem> items);

  /// Bulk-insert sale records into the database.
  Future<void> insertSales(List<SaleItem> items);

  /// Delete all purchase and sale records.
  Future<void> clearAll();

  /// Returns count of records per table: {'purchases': N, 'sales': M}.
  Future<Map<String, int>> getCounts();

  /// Top [n] items ranked by total sales revenue.
  Future<List<ItemAnalysis>> getTopItemsBySales(int n);

  /// Items that were purchased but have zero recorded sales.
  Future<List<ItemAnalysis>> getDeadstock();

  /// Profit/loss report for all items (joined purchase + sales).
  Future<List<ItemAnalysis>> getProfitReport();

  /// Full-text search across item names in both tables.
  /// Returns raw maps tagged with 'record_type': 'purchase' | 'sale'.
  Future<List<Map<String, dynamic>>> searchByName(String name);
}
