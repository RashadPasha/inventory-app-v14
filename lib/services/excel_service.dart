import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database.dart';
import '../models.dart';

class ImportResult {
  const ImportResult({required this.imported, required this.skipped, required this.messages});
  final int imported;
  final int skipped;
  final List<String> messages;
}

class ExcelService {
  ExcelService(this.db);
  final AppDatabase db;

  Future<_PickedTable?> _pickTable() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final ext = p.extension(file.name).toLowerCase();
    if (ext == '.csv') {
      final text = String.fromCharCodes(bytes);
      final rows = const CsvToListConverter(shouldParseNumbers: false).convert(text);
      return _PickedTable(file.name, rows.map((r) => r.map((e) => e.toString()).toList()).toList());
    }

    final book = Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) return _PickedTable(file.name, const []);
    final sheet = book.tables.values.first;
    final rows = sheet.rows
        .map((r) => r.map((cell) => cell?.value?.toString().trim() ?? '').toList())
        .toList();
    return _PickedTable(file.name, rows);
  }

  Future<ImportResult?> importProducts(int companyId) async {
    final table = await _pickTable();
    if (table == null) return null;
    if (table.rows.isEmpty) {
      return const ImportResult(imported: 0, skipped: 0, messages: ['Faylda məlumat tapılmadı.']);
    }
    final header = _headerMap(table.rows.first);
    final idxName = _find(header, ['ad', 'mehsuladi', 'productname', 'name']);
    final idxCode = _find(header, ['kod', 'code', 'sku']);
    final idxCategory = _find(header, ['kateqoriya', 'category', 'nov']);
    final idxSub = _find(header, ['altkateqoriya', 'subcategory', 'subcat']);
    final idxUnit = _find(header, ['olcuvahidi', 'vahid', 'unit']);
    final idxPrice = _find(header, ['vahidinprice', 'vahidin qiymeti', 'vahidinqiymeti', 'qiymet', 'unitprice', 'price']);
    final idxBarcode = _find(header, ['barkod', 'barcode']);

    if (idxName == null || idxCode == null) {
      return const ImportResult(
        imported: 0,
        skipped: 0,
        messages: ['Məcburi sütunlar tapılmadı: Kod və Məhsulun adı.'],
      );
    }

    var imported = 0;
    var skipped = 0;
    final messages = <String>[];
    for (var i = 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      final name = _cell(row, idxName);
      final code = _cell(row, idxCode);
      if (name.isEmpty && code.isEmpty) continue;
      if (name.isEmpty || code.isEmpty) {
        skipped++;
        messages.add('${i + 1}-ci sətir: Kod və ya ad boşdur.');
        continue;
      }
      final rawCategory = idxCategory == null ? 'Mal' : _cell(row, idxCategory);
      final category = _category(rawCategory);
      final sub = idxSub == null ? '' : _cell(row, idxSub);
      final unit = idxUnit == null || _cell(row, idxUnit).isEmpty ? 'ədəd' : _cell(row, idxUnit);
      final price = idxPrice == null ? 0.0 : _number(_cell(row, idxPrice));
      final barcode = idxBarcode == null ? null : _cell(row, idxBarcode);
      try {
        await db.upsertProduct(
          companyId: companyId,
          category: category,
          subcategory: sub,
          code: code,
          barcode: barcode,
          name: name,
          unit: unit,
          unitPrice: price,
        );
        imported++;
      } catch (e) {
        skipped++;
        messages.add('${i + 1}-ci sətir: $e');
      }
    }
    return ImportResult(imported: imported, skipped: skipped, messages: messages.take(20).toList());
  }

  Future<ImportResult?> importStockBalances({
    required int companyId,
    required int warehouseId,
  }) async {
    final table = await _pickTable();
    if (table == null) return null;
    if (table.rows.isEmpty) {
      return const ImportResult(imported: 0, skipped: 0, messages: ['Faylda məlumat tapılmadı.']);
    }
    final header = _headerMap(table.rows.first);
    final idxName = _find(header, ['ad', 'mehsuladi', 'productname', 'name']);
    final idxCode = _find(header, ['kod', 'code', 'sku']);
    final idxUnit = _find(header, ['olcuvahidi', 'vahid', 'unit']);
    final idxQty = _find(header, ['sonqaliq', 'qaliq', 'quantity', 'qty', 'stock']);
    final idxAmount = _find(header, ['cemimebleg', 'cemimeblegi', 'qaliqmeblegi', 'totalamount', 'amount']);

    if (idxQty == null || (idxName == null && idxCode == null)) {
      return const ImportResult(
        imported: 0,
        skipped: 0,
        messages: ['Məcburi sütunlar tapılmadı: Son qalıq və Məhsul adı/Kod.'],
      );
    }

    final products = await db.getProducts(companyId: companyId);
    final byCode = <String, Product>{for (final p in products) _norm(p.code): p};
    final byNameUnit = <String, Product>{for (final p in products) '${_norm(p.name)}|${_norm(p.unit)}': p};
    final byName = <String, Product>{for (final p in products) _norm(p.name): p};

    var imported = 0;
    var skipped = 0;
    final messages = <String>[];
    for (var i = 1; i < table.rows.length; i++) {
      final row = table.rows[i];
      final code = idxCode == null ? '' : _cell(row, idxCode);
      final name = idxName == null ? '' : _cell(row, idxName);
      final unit = idxUnit == null ? '' : _cell(row, idxUnit);
      if (code.isEmpty && name.isEmpty) continue;
      Product? product;
      if (code.isNotEmpty) product = byCode[_norm(code)];
      product ??= unit.isNotEmpty ? byNameUnit['${_norm(name)}|${_norm(unit)}'] : null;
      product ??= byName[_norm(name)];
      if (product == null) {
        skipped++;
        messages.add('${i + 1}-ci sətir: "$name" məhsulu sistemdə tapılmadı.');
        continue;
      }
      final qty = _number(_cell(row, idxQty));
      final amount = idxAmount == null ? qty * product.unitPrice : _number(_cell(row, idxAmount));
      await db.setStockBalance(
        warehouseId: warehouseId,
        productId: product.id,
        quantity: qty,
        totalAmount: amount,
      );
      imported++;
    }
    return ImportResult(imported: imported, skipped: skipped, messages: messages.take(20).toList());
  }

  Future<String> exportInventoryXlsx(InventoryHeader inventory, List<InventoryLineView> lines) async {
    final book = Excel.createExcel();
    final sheet = book['Inventarizasiya'];
    if (book.tables.containsKey('Sheet1')) book.delete('Sheet1');
    sheet.appendRow(_textRow([
      'Kateqoriya',
      'Alt kateqoriya',
      'Kod',
      'Məhsul',
      'Ölçü vahidi',
      'Sistem qalığı',
      'Faktiki sayım',
      'Fərq',
      'Vahid qiyməti',
      'Fərqin məbləği',
    ]));
    for (final line in lines) {
      sheet.appendRow(_textRow([
        line.category,
        line.subcategory,
        line.code,
        line.productName,
        line.unit,
        _fmt(line.systemQty),
        line.actualQty == null ? '' : _fmt(line.actualQty!),
        line.difference == null ? '' : _fmt(line.difference!),
        _fmt(line.unitPrice),
        line.differenceAmount == null ? '' : _fmt(line.differenceAmount!),
      ]));
    }
    final bytes = book.encode();
    if (bytes == null) throw StateError('Excel faylı yaradıla bilmədi.');
    final dir = await getTemporaryDirectory();
    final fileName = 'Muno_Inventory_${inventory.inventoryDate}_#${inventory.id}.xlsx';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Muno Inventory nəticəsi');
    return file.path;
  }

  Future<String> exportInventoryCsv(InventoryHeader inventory, List<InventoryLineView> lines) async {
    final rows = <List<Object?>>[
      [
        'Kateqoriya',
        'Alt kateqoriya',
        'Kod',
        'Məhsul',
        'Ölçü vahidi',
        'Sistem qalığı',
        'Faktiki sayım',
        'Fərq',
        'Vahid qiyməti',
        'Fərqin məbləği',
      ],
      ...lines.map((line) => [
            line.category,
            line.subcategory,
            line.code,
            line.productName,
            line.unit,
            line.systemQty,
            line.actualQty ?? '',
            line.difference ?? '',
            line.unitPrice,
            line.differenceAmount ?? '',
          ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final fileName = 'Muno_Inventory_${inventory.inventoryDate}_#${inventory.id}.csv';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(csv, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Muno Inventory nəticəsi');
    return file.path;
  }

  List<TextCellValue> _textRow(List<String> values) => values.map(TextCellValue.new).toList();

  String _fmt(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Map<String, int> _headerMap(List<String> row) {
    final map = <String, int>{};
    for (var i = 0; i < row.length; i++) {
      map[_norm(row[i])] = i;
    }
    return map;
  }

  int? _find(Map<String, int> header, List<String> candidates) {
    for (final value in candidates) {
      final found = header[_norm(value)];
      if (found != null) return found;
    }
    return null;
  }

  String _cell(List<String> row, int index) => index < row.length ? row[index].trim() : '';

  double _number(String value) {
    final cleaned = value
        .replaceAll('₼', '')
        .replaceAll('AZN', '')
        .replaceAll(' ', '')
        .replaceAll('\u00a0', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  String _category(String value) {
    final n = _norm(value);
    if (n.contains('yarim')) return 'Yarımfabrikat';
    if (n.contains('mehsul')) return 'Məhsul';
    return 'Mal';
  }

  static String _norm(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ə', 'e')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

class _PickedTable {
  const _PickedTable(this.fileName, this.rows);
  final String fileName;
  final List<List<String>> rows;
}
