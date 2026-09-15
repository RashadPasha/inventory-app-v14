import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    final path = join(root, 'muno_inventory.db');
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE companies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('admin','user')),
        company_id INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(company_id) REFERENCES companies(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE warehouses(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        UNIQUE(company_id, name),
        FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        subcategory TEXT NOT NULL DEFAULT '',
        code TEXT NOT NULL,
        barcode TEXT,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(company_id, code),
        FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE stock_balances(
        warehouse_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL DEFAULT 0,
        total_amount REAL NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(warehouse_id, product_id),
        FOREIGN KEY(warehouse_id) REFERENCES warehouses(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE inventories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        company_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        inventory_date TEXT NOT NULL,
        responsible TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','closed')),
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        closed_at TEXT,
        FOREIGN KEY(company_id) REFERENCES companies(id),
        FOREIGN KEY(warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY(created_by) REFERENCES users(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE inventory_lines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inventory_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        system_qty REAL NOT NULL DEFAULT 0,
        actual_qty REAL,
        unit_price REAL NOT NULL DEFAULT 0,
        difference REAL,
        difference_amount REAL,
        UNIQUE(inventory_id, product_id),
        FOREIGN KEY(inventory_id) REFERENCES inventories(id) ON DELETE CASCADE,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');
  }

  String hashPassword(String password) {
    final bytes = utf8.encode('muno-inventory-v1::$password');
    return sha256.convert(bytes).toString();
  }

  Future<bool> hasUsers() async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users'));
    return (result ?? 0) > 0;
  }

  Future<AppUser> createFirstAdmin({
    required String fullName,
    required String username,
    required String password,
  }) async {
    final db = await database;
    final id = await db.insert('users', {
      'full_name': fullName.trim(),
      'username': username.trim().toLowerCase(),
      'password_hash': hashPassword(password),
      'role': 'admin',
      'company_id': null,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return AppUser(
      id: id,
      fullName: fullName.trim(),
      username: username.trim().toLowerCase(),
      role: 'admin',
      companyId: null,
      isActive: true,
    );
  }

  Future<AppUser?> login(String username, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ? AND password_hash = ? AND is_active = 1',
      whereArgs: [username.trim().toLowerCase(), hashPassword(password)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> getUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'full_name COLLATE NOCASE');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> createUser({
    required String fullName,
    required String username,
    required String password,
    required String role,
    int? companyId,
  }) async {
    final db = await database;
    final id = await db.insert('users', {
      'full_name': fullName.trim(),
      'username': username.trim().toLowerCase(),
      'password_hash': hashPassword(password),
      'role': role,
      'company_id': companyId,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _queue('user', id, 'upsert');
    return id;
  }

  Future<List<Company>> getCompanies({int? onlyCompanyId}) async {
    final db = await database;
    final rows = await db.query(
      'companies',
      where: onlyCompanyId == null ? null : 'id = ?',
      whereArgs: onlyCompanyId == null ? null : [onlyCompanyId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Company.fromMap).toList();
  }

  Future<int> createCompany(String name) async {
    final db = await database;
    final id = await db.insert('companies', {
      'name': name.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
    await _queue('company', id, 'upsert');
    return id;
  }

  Future<void> updateCompany(int id, String name) async {
    final db = await database;
    await db.update('companies', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
    await _queue('company', id, 'upsert');
  }

  Future<List<Warehouse>> getWarehouses({int? companyId}) async {
    final db = await database;
    final rows = await db.query(
      'warehouses',
      where: companyId == null ? null : 'company_id = ?',
      whereArgs: companyId == null ? null : [companyId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Warehouse.fromMap).toList();
  }

  Future<int> createWarehouse(int companyId, String name) async {
    final db = await database;
    final id = await db.insert('warehouses', {
      'company_id': companyId,
      'name': name.trim(),
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    await _queue('warehouse', id, 'upsert');
    return id;
  }

  Future<void> updateWarehouse(int id, String name) async {
    final db = await database;
    await db.update('warehouses', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
    await _queue('warehouse', id, 'upsert');
  }

  Future<List<Product>> getProducts({int? companyId, String? search}) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];
    if (companyId != null) {
      clauses.add('company_id = ?');
      args.add(companyId);
    }
    if (search != null && search.trim().isNotEmpty) {
      clauses.add('(name LIKE ? OR code LIKE ? OR barcode LIKE ?)');
      final value = '%${search.trim()}%';
      args.addAll([value, value, value]);
    }
    final rows = await db.query(
      'products',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'category, subcategory, name COLLATE NOCASE',
    );
    return rows.map(Product.fromMap).toList();
  }

  Future<int> upsertProduct({
    required int companyId,
    required String category,
    required String subcategory,
    required String code,
    String? barcode,
    required String name,
    required String unit,
    required double unitPrice,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'products',
      columns: ['id'],
      where: 'company_id = ? AND code = ?',
      whereArgs: [companyId, code.trim()],
      limit: 1,
    );
    int id;
    final values = {
      'company_id': companyId,
      'category': category.trim(),
      'subcategory': subcategory.trim(),
      'code': code.trim(),
      'barcode': (barcode == null || barcode.trim().isEmpty) ? null : barcode.trim(),
      'name': name.trim(),
      'unit': unit.trim(),
      'unit_price': unitPrice,
      'updated_at': now,
    };
    if (existing.isEmpty) {
      id = await db.insert('products', {...values, 'created_at': now});
    } else {
      id = existing.first['id'] as int;
      await db.update('products', values, where: 'id = ?', whereArgs: [id]);
    }
    await _queue('product', id, 'upsert');
    return id;
  }

  Future<void> setStockBalance({
    required int warehouseId,
    required int productId,
    required double quantity,
    required double totalAmount,
  }) async {
    final db = await database;
    await db.insert(
      'stock_balances',
      {
        'warehouse_id': warehouseId,
        'product_id': productId,
        'quantity': quantity,
        'total_amount': totalAmount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<StockBalanceView>> getStockBalances(int warehouseId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT sb.product_id, p.code, p.name product_name, p.unit,
             sb.quantity, sb.total_amount, sb.updated_at
      FROM stock_balances sb
      JOIN products p ON p.id = sb.product_id
      WHERE sb.warehouse_id = ?
      ORDER BY p.category, p.subcategory, p.name COLLATE NOCASE
    ''', [warehouseId]);
    return rows.map(StockBalanceView.fromMap).toList();
  }

  Future<Map<int, double>> getStockMap(int warehouseId) async {
    final db = await database;
    final rows = await db.query(
      'stock_balances',
      columns: ['product_id', 'quantity'],
      where: 'warehouse_id = ?',
      whereArgs: [warehouseId],
    );
    return {for (final row in rows) row['product_id'] as int: (row['quantity'] as num).toDouble()};
  }

  Future<int> createInventory({
    required int companyId,
    required int warehouseId,
    required String inventoryDate,
    required String responsible,
    required int createdBy,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final inventoryId = await txn.insert('inventories', {
        'company_id': companyId,
        'warehouse_id': warehouseId,
        'inventory_date': inventoryDate,
        'responsible': responsible.trim(),
        'status': 'draft',
        'created_by': createdBy,
        'created_at': now,
      });
      final products = await txn.query(
        'products',
        columns: ['id', 'unit_price'],
        where: 'company_id = ?',
        whereArgs: [companyId],
      );
      for (final product in products) {
        final productId = product['id'] as int;
        final balance = await txn.query(
          'stock_balances',
          columns: ['quantity'],
          where: 'warehouse_id = ? AND product_id = ?',
          whereArgs: [warehouseId, productId],
          limit: 1,
        );
        final systemQty = balance.isEmpty ? 0.0 : (balance.first['quantity'] as num).toDouble();
        await txn.insert('inventory_lines', {
          'inventory_id': inventoryId,
          'product_id': productId,
          'system_qty': systemQty,
          'actual_qty': null,
          'unit_price': (product['unit_price'] as num?)?.toDouble() ?? 0,
          'difference': null,
          'difference_amount': null,
        });
      }
      return inventoryId;
    });
  }

  Future<List<InventoryHeader>> getInventories({int? companyId}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.*, c.name company_name, w.name warehouse_name
      FROM inventories i
      JOIN companies c ON c.id = i.company_id
      JOIN warehouses w ON w.id = i.warehouse_id
      ${companyId == null ? '' : 'WHERE i.company_id = ?'}
      ORDER BY i.inventory_date DESC, i.id DESC
    ''', companyId == null ? null : [companyId]);
    return rows.map(InventoryHeader.fromMap).toList();
  }

  Future<InventoryHeader> getInventory(int inventoryId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT i.*, c.name company_name, w.name warehouse_name
      FROM inventories i
      JOIN companies c ON c.id = i.company_id
      JOIN warehouses w ON w.id = i.warehouse_id
      WHERE i.id = ?
    ''', [inventoryId]);
    return InventoryHeader.fromMap(rows.first);
  }

  Future<List<InventoryLineView>> getInventoryLines(int inventoryId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT il.id line_id, il.inventory_id, il.product_id,
             il.system_qty, il.actual_qty, il.unit_price,
             il.difference, il.difference_amount,
             p.category, p.subcategory, p.code, p.barcode,
             p.name product_name, p.unit
      FROM inventory_lines il
      JOIN products p ON p.id = il.product_id
      WHERE il.inventory_id = ?
      ORDER BY p.category, p.subcategory, p.name COLLATE NOCASE
    ''', [inventoryId]);
    return rows.map(InventoryLineView.fromMap).toList();
  }

  Future<void> updateActualQty(int lineId, double actualQty) async {
    final db = await database;
    final rows = await db.query(
      'inventory_lines',
      columns: ['system_qty', 'unit_price'],
      where: 'id = ?',
      whereArgs: [lineId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final systemQty = (rows.first['system_qty'] as num).toDouble();
    final unitPrice = (rows.first['unit_price'] as num).toDouble();
    final diff = actualQty - systemQty;
    await db.update(
      'inventory_lines',
      {
        'actual_qty': actualQty,
        'difference': diff,
        'difference_amount': diff * unitPrice,
      },
      where: 'id = ?',
      whereArgs: [lineId],
    );
  }

  Future<int> getMissingCount(int inventoryId) async {
    final db = await database;
    final result = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM inventory_lines WHERE inventory_id = ? AND actual_qty IS NULL',
      [inventoryId],
    ));
    return result ?? 0;
  }

  Future<void> closeInventory(int inventoryId) async {
    final db = await database;
    await db.transaction((txn) async {
      final missing = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM inventory_lines WHERE inventory_id = ? AND actual_qty IS NULL',
            [inventoryId],
          )) ??
          0;
      if (missing > 0) {
        throw StateError('$missing məhsul sayılmayıb');
      }
      await txn.update(
        'inventories',
        {'status': 'closed', 'closed_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [inventoryId],
      );
    });
    await _queue('inventory', inventoryId, 'upsert');
  }

  Future<DashboardStats> getStats({int? companyId}) async {
    final db = await database;
    Future<int> count(String table, {String? where, List<Object?>? args}) async {
      return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM $table${where == null ? '' : ' WHERE $where'}',
            args,
          )) ??
          0;
    }

    return DashboardStats(
      companies: companyId == null ? await count('companies') : 1,
      warehouses: await count('warehouses', where: companyId == null ? null : 'company_id = ?', args: companyId == null ? null : [companyId]),
      products: await count('products', where: companyId == null ? null : 'company_id = ?', args: companyId == null ? null : [companyId]),
      openInventories: await count(
        'inventories',
        where: companyId == null ? "status = 'draft'" : "company_id = ? AND status = 'draft'",
        args: companyId == null ? null : [companyId],
      ),
    );
  }

  Future<int> pendingSyncCount() async {
    final db = await database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE synced_at IS NULL')) ?? 0;
  }

  Future<void> _queue(String entityType, int entityId, String operation) async {
    final db = await database;
    await db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'created_at': DateTime.now().toIso8601String(),
      'synced_at': null,
    });
  }
}
