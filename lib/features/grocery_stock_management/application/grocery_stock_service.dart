import '../../../core/database/app_database.dart';
import '../data/models/grocery_stock_item.dart';

class GroceryStockService {
  GroceryStockService._();
  static final GroceryStockService instance = GroceryStockService._();

  void validateStockItemInput({
    required String itemName,
    required int quantityInStock,
    required double capitalPrice,
    required double retailPrice,
    required int minimumAlertQuantity,
  }) {
    if (itemName.trim().isEmpty) throw ArgumentError('Item name is required.');
    if (quantityInStock < 0) throw ArgumentError('Stock quantity cannot be negative.');
    if (capitalPrice < 0) throw ArgumentError('Capital price cannot be negative.');
    if (retailPrice < 0) throw ArgumentError('Retail price cannot be negative.');
    if (minimumAlertQuantity < 0) throw ArgumentError('Minimum alert quantity cannot be negative.');
  }

  Future<List<GroceryStockItem>> getStockItems() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.groceryStockRepository!.getAll();
  }

  Future<GroceryStockItem> addStockItem({
    required String itemName,
    required String stockNumber,
    required int quantityInStock,
    required double capitalPrice,
    required double retailPrice,
    required int minimumAlertQuantity,
    String? picturePath,
    required String category,
    DateTime? expirationDate,
    String? notes,
  }) async {
    validateStockItemInput(
      itemName: itemName,
      quantityInStock: quantityInStock,
      capitalPrice: capitalPrice,
      retailPrice: retailPrice,
      minimumAlertQuantity: minimumAlertQuantity,
    );

    await AppDatabase.instance.database;
    return AppDatabase.instance.groceryStockRepository!.create(
      GroceryStockItem(
        itemName: itemName.trim(),
        stockNumber: stockNumber.trim(),
        quantityInStock: quantityInStock,
        capitalPrice: capitalPrice,
        retailPrice: retailPrice,
        minimumAlertQuantity: minimumAlertQuantity,
        picturePath: picturePath,
        category: category.trim().isEmpty ? 'General' : category.trim(),
        expirationDate: expirationDate,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ),
    );
  }

  Future<GroceryStockItem> updateStockItem({
    required int id,
    required String itemName,
    required String stockNumber,
    required int quantityInStock,
    required double capitalPrice,
    required double retailPrice,
    required int minimumAlertQuantity,
    String? picturePath,
    required String category,
    DateTime? expirationDate,
    String? notes,
  }) async {
    validateStockItemInput(
      itemName: itemName,
      quantityInStock: quantityInStock,
      capitalPrice: capitalPrice,
      retailPrice: retailPrice,
      minimumAlertQuantity: minimumAlertQuantity,
    );

    await AppDatabase.instance.database;
    final repository = AppDatabase.instance.groceryStockRepository!;
    final existing = await repository.getById(id);
    if (existing == null) throw StateError('Stock item was not found.');

    return repository.update(
      existing.copyWith(
        itemName: itemName.trim(),
        stockNumber: stockNumber.trim(),
        quantityInStock: quantityInStock,
        capitalPrice: capitalPrice,
        retailPrice: retailPrice,
        minimumAlertQuantity: minimumAlertQuantity,
        picturePath: picturePath,
        category: category.trim().isEmpty ? 'General' : category.trim(),
        expirationDate: expirationDate,
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ),
    );
  }

  Future<void> deleteStockItem(int id) async {
    await AppDatabase.instance.database;
    await AppDatabase.instance.groceryStockRepository!.delete(id);
  }
}
