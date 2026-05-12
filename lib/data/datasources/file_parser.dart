import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../domain/entities/item.dart';

class FileParser {
  FileParser._();

  static List<SaleItem> parseSalesCsv(List<int> bytes) {
    String raw = _decodeBytes(bytes);
    if (raw.startsWith('﻿')) raw = raw.substring(1);

    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (raw[i] == '\r') {
        sb.write('\n');
        if (i + 1 < raw.length && raw[i + 1] == '\n') i++;
      } else {
        sb.write(raw[i]);
      }
    }
    raw = sb.toString();

    final firstNl = raw.indexOf('\n');
    final firstLine = firstNl == -1 ? raw : raw.substring(0, firstNl);
    final delimiter = firstLine.split('	').length > firstLine.split(',').length ? '	' : ',';

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
      itemCodeCol = _colIdx(headers, ['كود الصنف']);
      itemNameCol = _colIdx(headers, ['اسم الصنف']);
      branchCol = _colIdx(headers, ['اسم الفرع']);
      categoryCol = _colIdx(headers, ['اسم المجموعة فرعية', 'القسم']);
      qtyCol = _colIdx(headers, ['صافى كمية مبيعات', 'كمية مبيعات']);
      revenueCol = _colIdx(headers, ['صافى قيمة مبيعات', 'قيمة مبيعات']);
    } else {
      itemCodeCol = 8; itemNameCol = 10; branchCol = 1;
      categoryCol = 7; qtyCol = 11; revenueCol = 12;
    }

    final List<SaleItem> result = [];
    for (int i = headerIdx + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isEmptyRow(row)) continue;
      try {
        final itemName = _str(row, itemNameCol);
        final qty = _dbl(row, qtyCol);
        if (itemName.isEmpty || itemName.replaceAll('?', '').trim().isEmpty) continue;
        if (qty <= 0) continue;
        result.add(SaleItem(
          itemCode: _str(row, itemCodeCol),
          itemName: itemName,
          branchName: _str(row, branchCol),
          category: _str(row, categoryCol),
          quantity: qty,
          totalRevenue: _dbl(row, revenueCol),
        ));
      } catch (_) {}
    }
    return result;
  }

  static List<PurchaseItem> parsePurchasesXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<PurchaseItem> result = [];
    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      int headerIdx = -1;
      List<String> headers = [];
      for (int r = 0; r < sheet.rows.length && r < 15; r++) {
        final cells = _sheetRow(sheet, r);
        if (cells.any((c) => c.contains('إسم الصنف') || c.contains('اسم الصنف') || c.contains('كود الصنف'))) {
          headerIdx = r;
          headers = cells;
          break;
        }
      }
      if (headerIdx == -1) continue;

      final itemCodeCol = _colIdx(headers, ['كود الصنف']);
      final itemNameCol = _colIdx(headers, ['إسم الصنف', 'اسم الصنف']);
      final qtyCol = _colIdx(headers, ['صافى كمية المشتريات', 'كمية المشتريات', 'كمية']);
      final purchaseValCol = _colIdx(headers, ['قيمة المشتريات', 'صافى المشتريات']);

      for (int r = headerIdx + 1; r < sheet.rows.length; r++) {
        final cells = _sheetRow(sheet, r);
        if (_isEmptyRow(cells)) continue;
        try {
          final itemName = _safeCell(cells, itemNameCol);
          final itemCode = _safeCell(cells, itemCodeCol);
          if (itemName.contains('إجمالى') || itemName.contains('اجمالي') || itemName.isEmpty) continue;
          if (!_hasArabic(itemName) && itemCode.isEmpty) continue;
          final qty = _parseLocaleNum(_safeCell(cells, qtyCol));
          final value = _parseLocaleNum(_safeCell(cells, purchaseValCol));
          if (qty <= 0) continue;
          result.add(PurchaseItem(
            itemCode: itemCode,
            itemName: itemName,
            quantity: qty,
            totalCost: value,
          ));
        } catch (_) {}
      }
    }
    return result;
  }

  static Stream<List<SaleItem>> streamSalesCsvFromPath(String filePath, {int chunkSize = 2000}) async* {
    final file = File(filePath);
    final headerBytes = await file.openRead(0, 3).first;
    final hasBom = headerBytes.length >= 3 && headerBytes[0] == 0xEF && headerBytes[1] == 0xBB && headerBytes[2] == 0xBF;
    final startByte = hasBom ? 3 : 0;

    bool headerParsed = false;
    int itemCodeCol = 8, itemNameCol = 10, branchCol = 1, categoryCol = 7, qtyCol = 11, revenueCol = 12;
    final List<SaleItem> buffer = [];

    final lineStream = file.openRead(startByte).transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());

    await for (final line in lineStream) {
      if (line.trim().isEmpty) continue;
      try {
        final parsed = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert('$line\n');
        if (parsed.isEmpty) continue;
        final cells = parsed.first.map((c) => c.toString().trim()).toList();

        if (!headerParsed) {
          var hasArabicHeaders = cells.any((c) => _hasArabic(c));
          if (hasArabicHeaders) {
            itemCodeCol = _colIdx(cells, ['كود الصنف']);
            itemNameCol = _colIdx(cells, ['اسم الصنف']);
            branchCol = _colIdx(cells, ['اسم الفرع']);
            categoryCol = _colIdx(cells, ['اسم المجموعة فرعية', 'القسم']);
            qtyCol = _colIdx(cells, ['صافى كمية مبيعات', 'كمية مبيعات']);
            revenueCol = _colIdx(cells, ['صافى قيمة مبيعات', 'قيمة مبيعات']);
          }
          headerParsed = true;
          continue;
        }

        final name = _safeCell(cells, itemNameCol);
        final qty = _parseLocaleNum(_safeCell(cells, qtyCol));
        if (name.isEmpty || name.replaceAll('?', '').trim().isEmpty) continue;
        if (qty <= 0) continue;

        buffer.add(SaleItem(
          itemCode: _safeCell(cells, itemCodeCol),
          itemName: name,
          branchName: _safeCell(cells, branchCol),
          category: _safeCell(cells, categoryCol),
          quantity: qty,
          totalRevenue: _parseLocaleNum(_safeCell(cells, revenueCol)),
        ));

        if (buffer.length >= chunkSize) {
          yield List.of(buffer);
          buffer.clear();
        }
      } catch (_) {
        continue;
      }
    }
    if (buffer.isNotEmpty) yield List.of(buffer);
  }
  
  static Stream<List<PurchaseItem>> streamPurchasesCsvFromPath(String filePath, {int chunkSize = 2000}) async* {
    final file = File(filePath);
    final headerBytes = await file.openRead(0, 3).first;
    final hasBom = headerBytes.length >= 3 && headerBytes[0] == 0xEF && headerBytes[1] == 0xBB && headerBytes[2] == 0xBF;
    final startByte = hasBom ? 3 : 0;

    bool headerParsed = false;
    int itemCodeCol = -1, itemNameCol = -1, qtyCol = -1, costCol = -1;
    final List<PurchaseItem> buffer = [];

    final lineStream = file.openRead(startByte).transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());

    await for (final line in lineStream) {
      if (line.trim().isEmpty) continue;
      try {
        final parsed = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert('$line\n');
        if (parsed.isEmpty) continue;
        final cells = parsed.first.map((c) => c.toString().trim()).toList();

        if (!headerParsed) {
          if (cells.any((c) => c.contains('اسم الصنف') || c.contains('كود الصنف'))) {
            itemCodeCol = _colIdx(cells, ['كود الصنف']);
            itemNameCol = _colIdx(cells, ['إسم الصنف', 'اسم الصنف']);
            qtyCol = _colIdx(cells, ['صافى كمية المشتريات', 'كمية المشتريات', 'كمية']);
            costCol = _colIdx(cells, ['قيمة المشتريات', 'صافى المشتريات']);
            headerParsed = true;
          }
          continue;
        }

        final itemName = _safeCell(cells, itemNameCol);
        final itemCode = _safeCell(cells, itemCodeCol);
        if (itemName.contains('إجمالى') || itemName.contains('اجمالي') || itemName.isEmpty) continue;
        if (!_hasArabic(itemName) && itemCode.isEmpty) continue;

        final qty = _parseLocaleNum(_safeCell(cells, qtyCol));
        if (qty <= 0) continue;

        buffer.add(PurchaseItem(
          itemCode: itemCode,
          itemName: itemName,
          quantity: qty,
          totalCost: _parseLocaleNum(_safeCell(cells, costCol)),
        ));

        if (buffer.length >= chunkSize) {
          yield List.of(buffer);
          buffer.clear();
        }
      } catch (_) {
        continue;
      }
    }
    if (buffer.isNotEmpty) yield List.of(buffer);
  }

  static Future<List<PurchaseItem>> parsePurchasesXlsxFromPath(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return parsePurchasesXlsx(bytes);
  }

  static int _findHeaderRow(List<List> rows, List<String> keywords) {
    for (int i = 0; i < rows.length && i < 10; i++) {
      final cells = rows[i].map((c) => c.toString().trim()).toList();
      if (cells.any((c) => keywords.any((k) => c.contains(k)))) return i;
    }
    return -1;
  }

  static int _colIdx(List<String> headers, List<String> candidates) {
    for (final candidate in candidates) {
      final idx = headers.indexWhere((h) => h.contains(candidate));
      if (idx != -1) return idx;
    }
    return -1;
  }

  static List<String> _sheetRow(Sheet sheet, int rowIdx) =>
      sheet.rows[rowIdx].map((c) => c?.value?.toString().trim() ?? '').toList();

  static String _str(List row, int idx) => (idx < 0 || idx >= row.length) ? '' : row[idx].toString().trim();

  static double _dbl(List row, int idx) => _parseLocaleNum(_str(row, idx));

  static String _safeCell(List<String> cells, int idx) => (idx < 0 || idx >= cells.length) ? '' : cells[idx];

  static double _parseLocaleNum(String s) {
    if (s.isEmpty) return 0;
    final cleaned = s.replaceAll(',', '').replaceAll(' ', '').replaceAll('%', '');
    return double.tryParse(cleaned) ?? 0;
  }

  static bool _isEmptyRow(List row) => row.every((c) => c.toString().trim().isEmpty);

  static bool _hasArabic(String text) => RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  static String _decodeBytes(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}
