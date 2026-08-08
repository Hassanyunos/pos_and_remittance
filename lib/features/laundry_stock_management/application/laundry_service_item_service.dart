import '../../../core/database/app_database.dart';
import '../data/models/laundry_service_item.dart';

class LaundryServiceItemService {
  LaundryServiceItemService._();
  static final LaundryServiceItemService instance =
      LaundryServiceItemService._();

  void validateServiceInput({
    required String name,
    required double price,
  }) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Service name is required.');
    }
    if (price < 0) {
      throw ArgumentError('Service price cannot be negative.');
    }
  }

  Future<List<LaundryServiceItem>> getServices() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.laundryServiceRepository!.getAll();
  }

  Future<LaundryServiceItem> addService({
    required String name,
    required double price,
    required List<int> addOnItemIds,
    String? notes,
  }) async {
    validateServiceInput(name: name, price: price);

    await AppDatabase.instance.database;
    return AppDatabase.instance.laundryServiceRepository!.create(
      LaundryServiceItem(
        name: name.trim(),
        price: price,
        addOnItemIds: addOnItemIds.isEmpty ? null : addOnItemIds.join(','),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ),
    );
  }

  Future<LaundryServiceItem> updateService({
    required int id,
    required String name,
    required double price,
    required List<int> addOnItemIds,
    String? notes,
  }) async {
    validateServiceInput(name: name, price: price);

    await AppDatabase.instance.database;
    final repository = AppDatabase.instance.laundryServiceRepository!;
    final existing = await repository.getById(id);
    if (existing == null) throw StateError('Laundry service was not found.');

    return repository.update(
      existing.copyWith(
        name: name.trim(),
        price: price,
        addOnItemIds: addOnItemIds.isEmpty ? null : addOnItemIds.join(','),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ),
    );
  }

  Future<void> deleteService(int id) async {
    await AppDatabase.instance.database;
    await AppDatabase.instance.laundryServiceRepository!.delete(id);
  }
}
