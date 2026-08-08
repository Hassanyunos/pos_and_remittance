import '../../../core/database/app_database.dart';
import '../../customer_management/data/models/customer.dart';
import '../../customer_management/data/models/customer_balance_payment.dart';
import '../../customer_management/data/repositories/customer_balance_payment_repository.dart';
import '../../fund_management/data/models/fund.dart';
import '../../fund_management/data/repositories/fund_repository.dart';
import '../data/models/sale.dart';
import '../data/models/sale_item.dart';

class SalesCartItem {
  SalesCartItem({
    required this.stockItemId,
    required this.itemName,
    required this.itemBarcode,
    required this.quantity,
    required this.retailPrice,
  });

  final int stockItemId;
  final String itemName;
  final String itemBarcode;
  final int quantity;
  final double retailPrice;

  double get lineTotal => retailPrice * quantity;
}

class SalesTotals {
  SalesTotals({
    required this.totalPrice,
    required this.amountPayable,
    required this.changeAmount,
    required this.outstandingBalance,
    required this.acceptsCredit,
  });

  final double totalPrice;
  final double amountPayable;
  final double changeAmount;
  final double outstandingBalance;
  final bool acceptsCredit;
}

class SalesService {
  SalesService._();
  static final SalesService instance = SalesService._();

  SalesTotals calculateSaleTotals({
    required List<SalesCartItem> cartItems,
    required double amountPaid,
    CustomerStatus customerStatus = CustomerStatus.standard,
  }) {
    final totalPrice =
        cartItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final acceptsCredit = customerStatus == CustomerStatus.allowedToBorrow;

    if (!acceptsCredit && amountPaid < totalPrice) {
      throw ArgumentError(
          'Amount paid cannot be less than the payable amount.');
    }

    final outstandingBalance = acceptsCredit && amountPaid < totalPrice
        ? totalPrice - amountPaid
        : 0.0;

    return SalesTotals(
      totalPrice: totalPrice,
      amountPayable: totalPrice,
      changeAmount: amountPaid >= totalPrice ? amountPaid - totalPrice : 0,
      outstandingBalance: outstandingBalance,
      acceptsCredit: acceptsCredit,
    );
  }

  String generateReceiptNumber({DateTime? at}) {
    final timestamp = at ?? DateTime.now();
    final year = timestamp.year.toString();
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return 'POS-$year$month$day-$hour$minute$second';
  }

  double calculateDailySalesTotal({
    required List<Sale> sales,
    DateTime? at,
  }) {
    final targetDate = (at ?? DateTime.now()).toLocal();
    return sales.where((sale) {
      final soldAt = sale.soldAt.toLocal();
      return soldAt.year == targetDate.year &&
          soldAt.month == targetDate.month &&
          soldAt.day == targetDate.day;
    }).fold<double>(0, (sum, sale) => sum + sale.amountPayable);
  }

  double calculateNetCashCollected({
    required double amountPaid,
    required double amountPayable,
    required bool acceptsCredit,
  }) {
    if (!acceptsCredit && amountPaid < amountPayable) {
      throw ArgumentError(
          'Amount paid cannot be less than the payable amount.');
    }
    return amountPaid;
  }

  Future<List<Sale>> getSales() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.saleRepository!.getAll();
  }

  Future<Sale> createSale({
    required String receiptNumber,
    int? customerId,
    String? customerName,
    required List<SalesCartItem> cartItems,
    required double amountPaid,
    DateTime? soldAt,
    CustomerStatus customerStatus = CustomerStatus.standard,
  }) async {
    final totals = calculateSaleTotals(
      cartItems: cartItems,
      amountPaid: amountPaid,
      customerStatus: customerStatus,
    );
    await AppDatabase.instance.database;

    final stockRepository = AppDatabase.instance.groceryStockRepository!;
    final saleRepository = AppDatabase.instance.saleRepository!;
    final saleItemRepository = AppDatabase.instance.saleItemRepository!;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final customerRepository = AppDatabase.instance.customerRepository!;
    final balancePaymentRepository =
        CustomerBalancePaymentRepository(await AppDatabase.instance.database);

    final sale = Sale(
      receiptNumber: receiptNumber,
      customerId: customerId,
      customerName: customerName,
      totalPrice: totals.totalPrice,
      amountPayable: totals.amountPayable,
      amountPaid: amountPaid,
      changeAmount: totals.changeAmount,
      soldAt: soldAt ?? DateTime.now(),
      outstandingBalance: totals.outstandingBalance,
      isCreditSale: totals.outstandingBalance > 0,
    );

    final createdSale = await saleRepository.create(sale);

    for (final item in cartItems) {
      final stockItem = await stockRepository.getById(item.stockItemId);
      if (stockItem == null) {
        throw ArgumentError('Stock item ${item.itemName} was not found.');
      }
      if (stockItem.quantityInStock < item.quantity) {
        throw ArgumentError('Not enough stock for ${item.itemName}.');
      }
      await stockRepository.update(
        stockItem.copyWith(
            quantityInStock: stockItem.quantityInStock - item.quantity),
      );

      await saleItemRepository.create(
        SaleItem(
          saleId: createdSale.id!,
          itemName: item.itemName,
          itemBarcode: item.itemBarcode,
          quantityBought: item.quantity,
          retailPrice: item.retailPrice,
        ),
      );
    }

    final netCashCollected = calculateNetCashCollected(
      amountPaid: amountPaid,
      amountPayable: totals.amountPayable,
      acceptsCredit: totals.acceptsCredit,
    );

    if (customerId != null && totals.outstandingBalance > 0) {
      final existingCustomer = await customerRepository.getById(customerId);
      if (existingCustomer != null) {
        final nextBalance =
            existingCustomer.currentBalance + totals.outstandingBalance;
        await customerRepository
            .update(existingCustomer.copyWith(currentBalance: nextBalance));
        await balancePaymentRepository.create(
          CustomerBalancePayment(
            customerId: customerId,
            saleId: createdSale.id,
            amount: totals.outstandingBalance,
            paymentType: CustomerBalancePaymentType.credit,
            source: CustomerBalancePaymentSource.grocery,
            note: 'Balance carried from sale ${createdSale.receiptNumber}',
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    Fund? groceryFund;
    final funds = await fundRepository.getAll();
    for (final fund in funds) {
      if (fund.name == FundRepository.groceryCashName) {
        groceryFund = fund;
        break;
      }
    }

    if (groceryFund != null) {
      await fundRepository.update(groceryFund.copyWith(
          currentBalance: groceryFund.currentBalance + netCashCollected));
    }

    return createdSale;
  }
}
