import '../../../core/database/app_database.dart';

enum ArchiveEntityType {
  customer,
  groceryStock,
  laundryStock,
  laundryService,
  laundryOrder,
  fund,
  expense,
  remittance,
  sale,
}

class ArchivedRecord {
  const ArchivedRecord({
    required this.type,
    required this.recordId,
    required this.title,
    required this.subtitle,
    required this.archivedAt,
  });

  final ArchiveEntityType type;
  final int recordId;
  final String title;
  final String subtitle;
  final DateTime archivedAt;
}

class ArchiveService {
  ArchiveService._();

  static final ArchiveService instance = ArchiveService._();

  Future<List<ArchivedRecord>> getArchivedRecords() async {
    final database = await AppDatabase.instance.database;

    final rows = await database.rawQuery('''
      SELECT 'customer' AS entity_type, id AS record_id, name AS title,
             COALESCE(contact_number, '') AS subtitle, archived_at
      FROM customers
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'grocery_stock' AS entity_type, id AS record_id, item_name AS title,
             COALESCE(stock_number, '') AS subtitle, archived_at
      FROM grocery_stock_items
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'laundry_stock' AS entity_type, id AS record_id, item_name AS title,
             COALESCE(stock_number, '') AS subtitle, archived_at
      FROM laundry_stock_items
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'laundry_service' AS entity_type, id AS record_id, name AS title,
             COALESCE(notes, '') AS subtitle, archived_at
      FROM laundry_service_items
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'laundry_order' AS entity_type, id AS record_id, reference_number AS title,
             COALESCE(customer_name, '') AS subtitle, archived_at
      FROM laundry_orders
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'fund' AS entity_type, id AS record_id, name AS title,
             fund_type AS subtitle, archived_at
      FROM funds
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'expense' AS entity_type, id AS record_id, purpose AS title,
             COALESCE(person_name, '') AS subtitle, archived_at
      FROM expenses
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'remittance' AS entity_type, id AS record_id, reference_number AS title,
             remittance_type AS subtitle, archived_at
      FROM remittances
      WHERE archived_at IS NOT NULL
      UNION ALL
      SELECT 'sale' AS entity_type, id AS record_id, receipt_number AS title,
             COALESCE(customer_name, 'Walk-in') AS subtitle, archived_at
      FROM sales
      WHERE archived_at IS NOT NULL
      ORDER BY archived_at DESC
    ''');

    return rows.map((row) {
      final typeValue = row['entity_type'] as String;
      return ArchivedRecord(
        type: _parseType(typeValue),
        recordId: (row['record_id'] as num).toInt(),
        title: (row['title'] as String?)?.trim().isNotEmpty == true
            ? (row['title'] as String)
            : 'Untitled record',
        subtitle: ((row['subtitle'] as String?) ?? '').trim(),
        archivedAt: DateTime.parse(row['archived_at'] as String).toLocal(),
      );
    }).toList(growable: false);
  }

  Future<void> restoreRecord(ArchivedRecord record) async {
    await AppDatabase.instance.database;
    switch (record.type) {
      case ArchiveEntityType.customer:
        await AppDatabase.instance.customerRepository!.restore(record.recordId);
      case ArchiveEntityType.groceryStock:
        await AppDatabase.instance.groceryStockRepository!
            .restore(record.recordId);
      case ArchiveEntityType.laundryStock:
        await AppDatabase.instance.laundryStockRepository!
            .restore(record.recordId);
      case ArchiveEntityType.laundryService:
        await AppDatabase.instance.laundryServiceRepository!
            .restore(record.recordId);
      case ArchiveEntityType.laundryOrder:
        await AppDatabase.instance.laundryOrderRepository!.restore(record.recordId);
      case ArchiveEntityType.fund:
        await AppDatabase.instance.fundRepository!.restore(record.recordId);
      case ArchiveEntityType.expense:
        await AppDatabase.instance.expenseRepository!.restore(record.recordId);
      case ArchiveEntityType.remittance:
        await AppDatabase.instance.remittanceRepository!.restore(record.recordId);
      case ArchiveEntityType.sale:
        await AppDatabase.instance.saleRepository!.restore(record.recordId);
    }
  }

  String typeLabel(ArchiveEntityType type) {
    return switch (type) {
      ArchiveEntityType.customer => 'Customer',
      ArchiveEntityType.groceryStock => 'Grocery stock',
      ArchiveEntityType.laundryStock => 'Laundry stock',
      ArchiveEntityType.laundryService => 'Laundry service',
      ArchiveEntityType.laundryOrder => 'Laundry order',
      ArchiveEntityType.fund => 'Fund',
      ArchiveEntityType.expense => 'Expense',
      ArchiveEntityType.remittance => 'Remittance',
      ArchiveEntityType.sale => 'Sale',
    };
  }

  ArchiveEntityType _parseType(String value) {
    switch (value) {
      case 'customer':
        return ArchiveEntityType.customer;
      case 'grocery_stock':
        return ArchiveEntityType.groceryStock;
      case 'laundry_stock':
        return ArchiveEntityType.laundryStock;
      case 'laundry_service':
        return ArchiveEntityType.laundryService;
      case 'laundry_order':
        return ArchiveEntityType.laundryOrder;
      case 'fund':
        return ArchiveEntityType.fund;
      case 'expense':
        return ArchiveEntityType.expense;
      case 'remittance':
        return ArchiveEntityType.remittance;
      case 'sale':
      default:
        return ArchiveEntityType.sale;
    }
  }
}
