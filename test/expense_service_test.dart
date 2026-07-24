import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/features/expense_management/application/expense_service.dart';

void main() {
  group('ExpenseService validation', () {
    test('rejects empty amount', () {
      expect(
        () => ExpenseService.instance.validateExpenseInput(amount: 0, personName: 'Juan', purpose: 'Supplies'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty person name', () {
      expect(
        () => ExpenseService.instance.validateExpenseInput(amount: 100, personName: '   ', purpose: 'Supplies'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty purpose', () {
      expect(
        () => ExpenseService.instance.validateExpenseInput(amount: 100, personName: 'Juan', purpose: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
