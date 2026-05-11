import '../entities/item.dart';
import '../repositories/item_repository.dart';

/// Returns the top [n] items sorted by sales revenue descending.
class GetTopSalesUseCase {
  final ItemRepository _repo;
  GetTopSalesUseCase(this._repo);

  /// [n] — how many items to return (default 10).
  Future<List<ItemAnalysis>> call({int n = 10}) =>
      _repo.getTopItemsBySales(n);
}

/// Returns all items that were purchased but never sold (deadstock).
class GetDeadstockUseCase {
  final ItemRepository _repo;
  GetDeadstockUseCase(this._repo);
  Future<List<ItemAnalysis>> call() => _repo.getDeadstock();
}

/// Returns a full profit/loss report, sorted by profit descending.
class GetProfitReportUseCase {
  final ItemRepository _repo;
  GetProfitReportUseCase(this._repo);
  Future<List<ItemAnalysis>> call() => _repo.getProfitReport();
}

/// Searches items by name across purchases and sales tables.
class SearchItemsUseCase {
  final ItemRepository _repo;
  SearchItemsUseCase(this._repo);

  /// [query] — partial or full item name to search for.
  Future<List<Map<String, dynamic>>> call(String query) =>
      _repo.searchByName(query);
}
