import '../../../core/database/app_database.dart';
import '../data/models/grocery_stock_category.dart';

class GroceryStockCategoryService {
  GroceryStockCategoryService._();
  static final GroceryStockCategoryService instance = GroceryStockCategoryService._();

  Future<List<GroceryStockCategory>> getCategories() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.groceryStockCategoryRepository!.getAll();
  }

  Future<GroceryStockCategory> addCategory({required String name}) async {
    if (name.trim().isEmpty) throw ArgumentError('Category name is required.');
    await AppDatabase.instance.database;
    return AppDatabase.instance.groceryStockCategoryRepository!.create(
      GroceryStockCategory(name: name.trim()),
    );
  }
}
