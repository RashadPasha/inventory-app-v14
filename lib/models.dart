class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.role,
    required this.companyId,
    required this.isActive,
  });

  final int id;
  final String fullName;
  final String username;
  final String role;
  final int? companyId;
  final bool isActive;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(Map<String, Object?> map) => AppUser(
        id: map['id'] as int,
        fullName: map['full_name'] as String,
        username: map['username'] as String,
        role: map['role'] as String,
        companyId: map['company_id'] as int?,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}

class Company {
  const Company({required this.id, required this.name});
  final int id;
  final String name;

  factory Company.fromMap(Map<String, Object?> map) => Company(
        id: map['id'] as int,
        name: map['name'] as String,
      );
}

class Warehouse {
  const Warehouse({
    required this.id,
    required this.companyId,
    required this.name,
    required this.isActive,
  });

  final int id;
  final int companyId;
  final String name;
  final bool isActive;

  factory Warehouse.fromMap(Map<String, Object?> map) => Warehouse(
        id: map['id'] as int,
        companyId: map['company_id'] as int,
        name: map['name'] as String,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}

class Product {
  const Product({
    required this.id,
    required this.companyId,
    required this.category,
    required this.subcategory,
    required this.code,
    required this.barcode,
    required this.name,
    required this.unit,
    required this.unitPrice,
  });

  final int id;
  final int companyId;
  final String category;
  final String subcategory;
  final String code;
  final String? barcode;
  final String name;
  final String unit;
  final double unitPrice;

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id'] as int,
        companyId: map['company_id'] as int,
        category: map['category'] as String,
        subcategory: map['subcategory'] as String? ?? '',
        code: map['code'] as String,
        barcode: map['barcode'] as String?,
        name: map['name'] as String,
        unit: map['unit'] as String,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      );
}

class InventoryHeader {
  const InventoryHeader({
    required this.id,
    required this.companyId,
    required this.warehouseId,
    required this.inventoryDate,
    required this.responsible,
    required this.status,
    required this.createdBy,
    this.companyName,
    this.warehouseName,
  });

  final int id;
  final int companyId;
  final int warehouseId;
  final String inventoryDate;
  final String responsible;
  final String status;
  final int createdBy;
  final String? companyName;
  final String? warehouseName;

  bool get isClosed => status == 'closed';

  factory InventoryHeader.fromMap(Map<String, Object?> map) => InventoryHeader(
        id: map['id'] as int,
        companyId: map['company_id'] as int,
        warehouseId: map['warehouse_id'] as int,
        inventoryDate: map['inventory_date'] as String,
        responsible: map['responsible'] as String,
        status: map['status'] as String,
        createdBy: map['created_by'] as int,
        companyName: map['company_name'] as String?,
        warehouseName: map['warehouse_name'] as String?,
      );
}

class InventoryLineView {
  const InventoryLineView({
    required this.lineId,
    required this.inventoryId,
    required this.productId,
    required this.category,
    required this.subcategory,
    required this.code,
    required this.barcode,
    required this.productName,
    required this.unit,
    required this.systemQty,
    required this.actualQty,
    required this.unitPrice,
    required this.difference,
    required this.differenceAmount,
  });

  final int lineId;
  final int inventoryId;
  final int productId;
  final String category;
  final String subcategory;
  final String code;
  final String? barcode;
  final String productName;
  final String unit;
  final double systemQty;
  final double? actualQty;
  final double unitPrice;
  final double? difference;
  final double? differenceAmount;

  factory InventoryLineView.fromMap(Map<String, Object?> map) => InventoryLineView(
        lineId: map['line_id'] as int,
        inventoryId: map['inventory_id'] as int,
        productId: map['product_id'] as int,
        category: map['category'] as String,
        subcategory: map['subcategory'] as String? ?? '',
        code: map['code'] as String,
        barcode: map['barcode'] as String?,
        productName: map['product_name'] as String,
        unit: map['unit'] as String,
        systemQty: (map['system_qty'] as num?)?.toDouble() ?? 0,
        actualQty: (map['actual_qty'] as num?)?.toDouble(),
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        difference: (map['difference'] as num?)?.toDouble(),
        differenceAmount: (map['difference_amount'] as num?)?.toDouble(),
      );
}

class DashboardStats {
  const DashboardStats({
    required this.companies,
    required this.warehouses,
    required this.products,
    required this.openInventories,
  });

  final int companies;
  final int warehouses;
  final int products;
  final int openInventories;
}

class StockBalanceView {
  const StockBalanceView({
    required this.productId,
    required this.code,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.totalAmount,
    required this.updatedAt,
  });

  final int productId;
  final String code;
  final String productName;
  final String unit;
  final double quantity;
  final double totalAmount;
  final String updatedAt;

  factory StockBalanceView.fromMap(Map<String, Object?> map) => StockBalanceView(
        productId: map['product_id'] as int,
        code: map['code'] as String,
        productName: map['product_name'] as String,
        unit: map['unit'] as String,
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
        updatedAt: map['updated_at'] as String,
      );
}
