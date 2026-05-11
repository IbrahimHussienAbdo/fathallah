/// Represents a single purchased item record from the XLSX file.
class PurchaseItem {
  final String itemCode;
  final String itemName;

  /// Net purchased quantity after bonuses.
  final double quantity;

  /// Total net purchase cost (after returns).
  final double totalCost;

  const PurchaseItem({
    required this.itemCode,
    required this.itemName,
    required this.quantity,
    required this.totalCost,
  });

  /// Derived unit price = totalCost / quantity.
  double get unitPrice => quantity > 0 ? totalCost / quantity : 0;
}

/// Represents a single sold item record from the CSV file.
class SaleItem {
  final String itemCode;
  final String itemName;
  final String branchName;
  final String category;

  /// Net sold quantity.
  final double quantity;

  /// Net sales revenue.
  final double totalRevenue;

  const SaleItem({
    required this.itemCode,
    required this.itemName,
    required this.branchName,
    required this.category,
    required this.quantity,
    required this.totalRevenue,
  });

  /// Derived unit sale price.
  double get unitPrice => quantity > 0 ? totalRevenue / quantity : 0;
}

/// Aggregated analytics view of an item combining purchase and sales data.
class ItemAnalysis {
  final String itemCode;
  final String itemName;
  final double purchasedQty;
  final double soldQty;
  final double totalCost;
  final double totalRevenue;

  const ItemAnalysis({
    required this.itemCode,
    required this.itemName,
    required this.purchasedQty,
    required this.soldQty,
    required this.totalCost,
    required this.totalRevenue,
  });

  /// Net profit = revenue - cost.
  double get profit => totalRevenue - totalCost;

  /// Profit margin as percentage of revenue.
  double get profitMarginPct =>
      totalRevenue > 0 ? (profit / totalRevenue) * 100 : 0;

  /// Item is deadstock if purchased but never sold.
  bool get isDeadstock => soldQty == 0 && purchasedQty > 0;

  /// Remaining unsold stock.
  double get remainingQty => (purchasedQty - soldQty).clamp(0, double.infinity);
}
