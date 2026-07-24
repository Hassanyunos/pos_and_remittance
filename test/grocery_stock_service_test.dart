import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/features/grocery_stock_management/application/grocery_stock_service.dart';

void main() {
  group('GroceryStockService validation', () {
    test('rejects empty item name and invalid prices', () {
      expect(
        () => GroceryStockService.instance.validateStockItemInput(
          itemName: '   ',
          quantityInStock: 5,
          capitalPrice: 10,
          retailPrice: 15,
          minimumAlertQuantity: 2,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => GroceryStockService.instance.validateStockItemInput(
          itemName: 'Milk',
          quantityInStock: 5,
          capitalPrice: -1,
          retailPrice: 15,
          minimumAlertQuantity: 2,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('accepts valid stock input', () {
      expect(
        () => GroceryStockService.instance.validateStockItemInput(
          itemName: 'Milk',
          quantityInStock: 5,
          capitalPrice: 10,
          retailPrice: 15,
          minimumAlertQuantity: 2,
        ),
        returnsNormally,
      );
    });
  });
}
