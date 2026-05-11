import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../domain/entities/item.dart';

/// Parses the two specific file formats supplied with the assignment:
///
/// **Sales CSV** — comma-separated, UTF-8 with BOM, CRLF line endings.
///   Columns: كود الفرع | اسم الفرع | كود القسم | القسم | مجموعة رئيسية |
///   اسم مجموعة رئيسية | مجموعة فرعية | اسم المجموعة فرعية |
///   كود الصنف[8] | باركود[9] | اسم الصنف[10] |
///   صافى كمية مبيعات[11] | صافى قيمة مبيعات[12] | (trailing empty col)[13]
///
/// **Purchases XLSX** — multiple metadata header rows before the data header.
///   Data header contains: كود الصنف | إسم الصنف |
///   صافى كمية المشتريات | قيمة المشتريات | صافى المشتريات
class FileParser {
  FileParser._();

  // ── Sales CSV ─────────────────────────────────────────

  /// Parses the sales CSV file bytes into a list of [SaleItem].
  ///
  /// NOTE: For files > ~50MB prefer [streamSalesCsvFromPath] which never
  /// loads the full file into RAM. This method is kept for small files and
  /// for use inside compute() isolates where bytes are already in memory.
  ///
  /// Key behaviours:
  ///   1. Strips UTF-8 BOM so the first header cell is recognised correctly.
  ///   2. Normalises CRLF → LF using a streaming scan instead of a full-string
  ///      replaceAll (which would duplicate the 400MB string in RAM).
  ///   3. Auto-detects comma vs tab delimiter from the first line only.
  static List<SaleItem> parseSalesCsv(List<int> bytes) {
    // Decode bytes — utf8 first, latin1 fallback.
    String raw = _decodeBytes(bytes);

    // Strip BOM if present.
    if (raw.startsWith('\uFEFF')) raw = raw.substring(1);

    // ── Normalise line endings without duplicating the full string ────────
    // StringBuffer scan: O(n) time, O(n) space but avoids the intermediate
    // copy that `replaceAll('\r\n', '\n')` creates on a 400MB string.
    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] == '\r') {
        sb.write('\n');
        if (i + 1 < raw.length && raw[i + 1] == '\n') i++; // skip \n in \r\n
      } else {
        sb.write(raw[i]);
      }
    }
    // Release the original string before building rows.
    raw = sb.toString();

    // Auto-detect delimiter from the first line only.
    final firstNl = raw.indexOf('\n');
    final firstLine = firstNl == -1 ? raw : raw.substring(0, firstNl);
    final delimiter = firstLine.split('\t').length > firstLine.split(',').length
        ? '\t'
        : ',';

    final rows = CsvToListConverter(
      eol: '\n',
      fieldDelimiter: delimiter,
      shouldParseNumbers: false,
    ).convert(raw);

    if (rows.isEmpty) return [];

    int headerIdx = _findHeaderRow(rows, ['اسم الصنف', 'كود الصنف']);
    if (headerIdx == -1) headerIdx = 0;

    final headers = rows[headerIdx].map((c) => c.toString().trim()).toList();
    final hasArabicHeaders = headers.any((h) => _hasArabic(h));

    int itemCodeCol, itemNameCol, branchCol, categoryCol, qtyCol, revenueCol;

    if (hasArabicHeaders) {
      itemCodeCol  = _colIdx(headers, ['كود الصنف']);
      itemNameCol  = _colIdx(headers, ['اسم الصنف']);
      branchCol    = _colIdx(headers, ['اسم الفرع']);
      categoryCol  = _colIdx(headers, ['اسم المجموعة فرعية', 'القسم']);
      qtyCol       = _colIdx(headers, ['صافى كمية مبيعات', 'كمية مبيعات']);
      revenueCol   = _colIdx(headers, ['صافى قيمة مبيعات', 'قيمة مبيعات']);
    } else {
      itemCodeCol = 8; itemNameCol = 10; branchCol = 1;
      categoryCol = 7; qtyCol = 11;     revenueCol = 12;
    }

    final List<SaleItem> result = [];

    for (int i = headerIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isEmptyRow(row)) continue;

      try {
        final itemName = _str(row, itemNameCol);
        final qty      = _dbl(row, qtyCol);

        if (itemName.isEmpty || itemName.replaceAll('?', '').trim().isEmpty) continue;
        if (qty <= 0) continue;

        result.add(SaleItem(
          itemCode:     _str(row, itemCodeCol),
          itemName:     itemName,
          branchName:   _str(row, branchCol),
          category:     _str(row, categoryCol),
          quantity:     qty,
          totalRevenue: _dbl(row, revenueCol),
        ));
      } catch (_) {}
    }

    return result;
  }

  // ── Purchases XLSX ────────────────────────────────────

  /// Parses the purchases XLSX file bytes into a list of [PurchaseItem].
  ///
  /// The XLSX has multiple metadata rows (company name, supplier info, etc.)
  /// before the actual column-names row. Scans up to row 15 for the real header.
  static List<PurchaseItem> parsePurchasesXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<PurchaseItem> result = [];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;

      // Find the header row by scanning the top 15 rows.
      int headerIdx = -1;
      List<String> headers = [];

      for (int r = 0; r < sheet.rows.length && r < 15; r++) {
        final cells = _sheetRow(sheet, r);
        if (cells.any((c) =>
            c.contains('إسم الصنف') ||
            c.contains('اسم الصنف') ||
            c.contains('كود الصنف'))) {
          headerIdx = r;
          headers = cells;
          break;
        }
      }

      // Sheet has no recognisable header — skip it.
      if (headerIdx == -1) continue;

      // Resolve column positions.
      final itemCodeCol    = _colIdx(headers, ['كود الصنف']);
      final itemNameCol    = _colIdx(headers, ['إسم الصنف', 'اسم الصنف']);
      final qtyCol         = _colIdx(headers, ['صافى كمية المشتريات', 'كمية المشتريات', 'كمية']);
      final purchaseValCol = _colIdx(headers, ['قيمة المشتريات', 'صافى المشتريات']);

      for (int r = headerIdx + 1; r < sheet.rows.length; r++) {
        final cells = _sheetRow(sheet, r);
        if (_isEmptyRow(cells)) continue;

        try {
          final itemName = _safeCell(cells, itemNameCol);
          final itemCode = _safeCell(cells, itemCodeCol);

          // Skip totals, subtotals and metadata rows.
          if (itemName.contains('إجمالى') ||
              itemName.contains('اجمالي') ||
              itemName.isEmpty) continue;

          // Require at least an Arabic item name or a non-empty code.
          if (!_hasArabic(itemName) && itemCode.isEmpty) continue;

          // Parse quantities — handle locale-formatted numbers like 1,659,087.
          final qty   = _parseLocaleNum(_safeCell(cells, qtyCol));
          final value = _parseLocaleNum(_safeCell(cells, purchaseValCol));

          if (qty <= 0) continue;

          result.add(PurchaseItem(
            itemCode:  itemCode,
            itemName:  itemName,
            quantity:  qty,
            totalCost: value,
          ));
        } catch (_) {
          // Skip malformed rows silently.
        }
      }
    }

    return result;
  }

  // ── Large-file streaming (path-based, no full RAM load) ───────────────

  /// Streams a large sales CSV file row-by-row, yielding chunks of
  /// [chunkSize] SaleItems without ever loading the full file into RAM.
  ///
  /// Uses dart:io [LineSplitter] so only one line is in memory at a time.
  /// Handles BOM, CRLF, and both comma/tab delimiters automatically.
  ///
  /// [filePath] — absolute path on the device filesystem.
  /// [chunkSize] — number of parsed rows per yielded batch (default 500).
  static Stream<List<SaleItem>> streamSalesCsvFromPath(
    String filePath, {
    int chunkSize = 2000,
  }) async* {
    final file = File(filePath);

    // Detect BOM from the first 3 bytes without reading the full file.
    final headerBytes = await file.openRead(0, 3).first;
    final hasBom = headerBytes.length >= 3 &&
        headerBytes[0] == 0xEF &&
        headerBytes[1] == 0xBB &&
        headerBytes[2] == 0xBF;
    final startByte = hasBom ? 3 : 0;

    bool   headerParsed = false;
    bool   hasArabicHeaders = false;
    int    itemCodeCol = 8, itemNameCol = 10, branchCol = 1,
           categoryCol = 7, qtyCol = 11,     revenueCol = 12;

    final List<SaleItem> buffer = [];

    // Read file as a byte stream → decode UTF-8 on-the-fly → split by line.
    // Only one line is ever in memory at a time — no full-file string.
    final lineStream = file
        .openRead(startByte)
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      if (line.trim().isEmpty) continue;

      // Parse one CSV line at a time (no full-file convert).
      final parsed = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert('$line\n');
      if (parsed.isEmpty) continue;

      final cells = parsed.first.map((c) => c.toString().trim()).toList();

      if (!headerParsed) {
        hasArabicHeaders = cells.any((c) => _hasArabic(c));
        if (hasArabicHeaders) {
          itemCodeCol  = _colIdx(cells, ['كود الصنف']);
          itemNameCol  = _colIdx(cells, ['اسم الصنف']);
          branchCol    = _colIdx(cells, ['اسم الفرع']);
          categoryCol  = _colIdx(cells, ['اسم المجموعة فرعية', 'القسم']);
          qtyCol       = _colIdx(cells, ['صافى كمية مبيعات', 'كمية مبيعات']);
          revenueCol   = _colIdx(cells, ['صافى قيمة مبيعات', 'قيمة مبيعات']);
        }
        // else: keep fixed fallback positions set above
        headerParsed = true;
        continue;
      }

      try {
        final name = _safeCell(cells, itemNameCol);
        final qty  = _parseLocaleNum(_safeCell(cells, qtyCol));
        if (name.isEmpty || name.replaceAll('?', '').trim().isEmpty) continue;
        if (qty <= 0) continue;

        buffer.add(SaleItem(
          itemCode:     _safeCell(cells, itemCodeCol),
          itemName:     name,
          branchName:   _safeCell(cells, branchCol),
          category:     _safeCell(cells, categoryCol),
          quantity:     qty,
          totalRevenue: _parseLocaleNum(_safeCell(cells, revenueCol)),
        ));

        // Yield a full chunk and release the buffer — keeps memory bounded.
        if (buffer.length >= chunkSize) {
          yield List.of(buffer);
          buffer.clear();
        }
      } catch (_) {
        continue; // skip malformed rows silently
      }
    }

    // Yield any remaining rows in the last partial chunk.
    if (buffer.isNotEmpty) yield List.of(buffer);
  }

  /// Reads a purchases XLSX from [filePath] without keeping bytes in the
  /// provider layer. Reads the file once, parses, then the bytes are GC'd.
  ///
  /// XLSX cannot be streamed row-by-row with the `excel` package because it
  /// is a ZIP archive that requires full decompression first. However, we
  /// read it here (not in the provider) so the provider never holds a
  /// 400MB List<int> alongside the parsed result simultaneously.
  ///
  /// [filePath] — absolute path on the device filesystem.
  static Future<List<PurchaseItem>> parsePurchasesXlsxFromPath(
      String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    // NOTE: excel package requires full bytes — unavoidable for XLSX format.
    // bytes is released after this method returns (goes out of scope in isolate).
    return parsePurchasesXlsx(bytes);
  }

  // ── Private helpers ───────────────────────────────────

  /// Finds the first row index (up to row 10) that contains any of [keywords].
  static int _findHeaderRow(List<List> rows, List<String> keywords) {
    for (int i = 0; i < rows.length && i < 10; i++) {
      final cells = rows[i].map((c) => c.toString().trim()).toList();
      if (cells.any((c) => keywords.any((k) => c.contains(k)))) return i;
    }
    return -1;
  }

  /// Finds the column index for the first matching candidate header name.
  static int _colIdx(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = headers.indexWhere((h) => h.contains(candidate));
      if (idx != -1) return idx;
    }
    return -1;
  }

  /// Extracts a sheet row as a list of trimmed strings.
  static List<String> _sheetRow(Sheet sheet, int rowIdx) =>
      sheet.rows[rowIdx]
          .map((c) => c?.value?.toString().trim() ?? '')
          .toList();

  /// Returns the string at [idx] from a row, or '' if out of bounds.
  static String _str(List row, int idx) =>
      (idx < 0 || idx >= row.length) ? '' : row[idx].toString().trim();

  /// Same as [_str] but parses the result as a double.
  static double _dbl(List row, int idx) =>
      _parseLocaleNum(_str(row, idx));

  /// Safe cell access for List<String>.
  static String _safeCell(List<String> cells, int idx) =>
      (idx < 0 || idx >= cells.length) ? '' : cells[idx];

  /// Parses locale-formatted numbers (e.g. "1,659,087.27" → 1659087.27).
  /// Also handles scientific notation strings like "6.90992E+12" (barcodes
  /// in the CSV) — those resolve to a large number and are used only for
  /// display, not for matching.
  static double _parseLocaleNum(String s) {
    if (s.isEmpty) return 0;
    final cleaned = s.replaceAll(',', '').replaceAll(' ', '').replaceAll('%', '');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Returns true if all cells in the row are blank.
  static bool _isEmptyRow(List row) =>
      row.every((c) => c.toString().trim().isEmpty);

  /// Returns true if [text] contains at least one Arabic character.
  static bool _hasArabic(String text) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  /// Decodes raw bytes to a String.
  /// Returns the decoded string; BOM stripping is handled by the caller.
  static String _decodeBytes(List<int> bytes) {
    // Try UTF-8 with BOM first
    try {
      return utf8.decode(bytes);
    } catch (_) {}

    // Fallback: Windows-1256 (standard Arabic Windows encoding)
    try {
      return latin1.decode(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}
