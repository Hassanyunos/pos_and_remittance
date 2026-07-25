import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/features/sales_management/application/sales_service.dart';

void main() {
  group('SalesService totals', () {
    test('calculates payable and change from cart items', () {
      final result = SalesService.instance.calculateSaleTotals(
        cartItems: [
          SalesCartItem(
            stockItemId: 1,
            itemName: 'Sugar',
            itemBarcode: '111',
            quantity: 2,
            retailPrice: 25,
          ),
          SalesCartItem(
            stockItemId: 2,
            itemName: 'Rice',
            itemBarcode: '222',
            quantity: 1,
            retailPrice: 40,
          ),
        ],
        amountPaid: 120,
      );

      expect(result.totalPrice, 90);
      expect(result.amountPayable, 90);
      expect(result.changeAmount, 30);
    });

    test('rejects amount paid below payable amount', () {
      expect(
        () => SalesService.instance.calculateSaleTotals(
          cartItems: [
            SalesCartItem(
              stockItemId: 1,
              itemName: 'Sugar',
              itemBarcode: '111',
              quantity: 1,
              retailPrice: 10,
            ),
          ],
          amountPaid: 5,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('generates a POS receipt number from the current timestamp', () {
      final receiptNumber = SalesService.instance.generateReceiptNumber(
        at: DateTime(2026, 7, 25, 9, 30, 15),
      );

      expect(receiptNumber, 'POS-20260725-093015');
    });
  });
}
