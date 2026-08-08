import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/features/customer_management/data/models/customer.dart';
import 'package:pos_and_remittance/features/customer_management/data/models/customer_balance_payment.dart';
import 'package:pos_and_remittance/features/home/presentation/pages/dashboard_page.dart';
import 'package:pos_and_remittance/features/sales_management/data/models/sale.dart';
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

    test('rejects amount paid below payable amount for standard customers', () {
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
          customerStatus: CustomerStatus.standard,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('allows partial payment for customers allowed to borrow', () {
      final result = SalesService.instance.calculateSaleTotals(
        cartItems: [
          SalesCartItem(
            stockItemId: 1,
            itemName: 'Sugar',
            itemBarcode: '111',
            quantity: 1,
            retailPrice: 10,
          ),
        ],
        amountPaid: 6,
        customerStatus: CustomerStatus.allowedToBorrow,
      );

      expect(result.totalPrice, 10);
      expect(result.amountPayable, 10);
      expect(result.changeAmount, 0);
      expect(result.outstandingBalance, 4);
      expect(result.acceptsCredit, true);
    });

    test('generates a POS receipt number from the current timestamp', () {
      final receiptNumber = SalesService.instance.generateReceiptNumber(
        at: DateTime(2026, 7, 25, 9, 30, 15),
      );

      expect(receiptNumber, 'POS-20260725-093015');
    });

    test('sums balance-payment cash collected inside the selected period', () {
      final payments = [
        CustomerBalancePayment(
          customerId: 1,
          amount: 50,
          paymentType: CustomerBalancePaymentType.payment,
          createdAt: DateTime(2026, 1, 10),
        ),
        CustomerBalancePayment(
          customerId: 1,
          amount: 20,
          paymentType: CustomerBalancePaymentType.payment,
          createdAt: DateTime(2026, 2, 1),
        ),
        CustomerBalancePayment(
          customerId: 1,
          amount: 15,
          paymentType: CustomerBalancePaymentType.credit,
          createdAt: DateTime(2026, 1, 12),
        ),
      ];

      final collected = calculateCollectedBalancePayments(
        payments: payments,
        start: DateTime(2026, 1, 1),
        end: DateTime(2026, 1, 31, 23, 59, 59),
      );

      expect(collected, 50);
    });

    test('calculates grocery sales from received amount excluding change', () {
      final sales = [
        Sale(
          receiptNumber: 'POS-1001',
          totalPrice: 100,
          amountPayable: 100,
          amountPaid: 150,
          changeAmount: 50,
          soldAt: DateTime(2026, 1, 10),
        ),
        Sale(
          receiptNumber: 'POS-1002',
          totalPrice: 100,
          amountPayable: 100,
          amountPaid: 40,
          changeAmount: 0,
          soldAt: DateTime(2026, 1, 11),
          outstandingBalance: 60,
          isCreditSale: true,
        ),
      ];

      final received = calculateReceivedSalesAmount(sales: sales);

      expect(received, 140);
    });

    test('excludes already paid customer debt from outstanding balance', () {
      final sales = [
        Sale(
          id: 1,
          receiptNumber: 'POS-1',
          customerId: 1,
          customerName: 'Ana',
          totalPrice: 100,
          amountPayable: 100,
          amountPaid: 40,
          changeAmount: 0,
          soldAt: DateTime(2026, 1, 10),
          outstandingBalance: 60,
          isCreditSale: true,
        ),
      ];

      final payments = [
        CustomerBalancePayment(
          customerId: 1,
          saleId: 1,
          amount: 20,
          paymentType: CustomerBalancePaymentType.payment,
          createdAt: DateTime(2026, 1, 11),
        ),
        CustomerBalancePayment(
          customerId: 1,
          saleId: 1,
          amount: 40,
          paymentType: CustomerBalancePaymentType.payment,
          createdAt: DateTime(2026, 1, 12),
        ),
      ];

      final outstandingAfterPartial = calculateCustomerOutstandingBalance(
        sales: sales,
        payments: payments,
        asOf: DateTime(2026, 1, 11),
      );
      final outstandingAfterFullPayment = calculateCustomerOutstandingBalance(
        sales: sales,
        payments: payments,
        asOf: DateTime(2026, 1, 12),
      );

      expect(outstandingAfterPartial, 40);
      expect(outstandingAfterFullPayment, 0);
    });
  });
}
