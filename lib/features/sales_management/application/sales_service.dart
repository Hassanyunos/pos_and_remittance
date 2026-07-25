import '../../../core/database/app_database.dart';
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
  });

  final double totalPrice;
  final double amountPayable;
  final double changeAmount;
}

class SalesService {
  SalesService._();
  static final SalesService instance = SalesService._();

  SalesTotals calculateSaleTotals({
    required List<SalesCartItem> cartItems,
    required double amountPaid,
  }) {
    final totalPrice = cartItems.fold<double>(0, (sum, item) => sum + item.lineTotal);
    if (amountPaid < totalPrice) {
      throw ArgumentError('Amount paid cannot be less than the payable amount.');
    }

    return SalesTotals(
      totalPrice: totalPrice,
      amountPayable: totalPrice,
      changeAmount: amountPaid - totalPrice,
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
      return soldAt.year == targetDate.year && soldAt.month == targetDate.month && soldAt.day == targetDate.day;
    }).fold<double>(0, (sum, sale) => sum + sale.amountPayable);
  }

  double calculateNetCashCollected({
    required double amountPaid,
    required double amountPayable,
  }) {
    if (amountPaid < amountPayable) {
      throw ArgumentError('Amount paid cannot be less than the payable amount.');
    }
    return amountPayable;
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
  }) async {
    final totals = calculateSaleTotals(cartItems: cartItems, amountPaid: amountPaid);
    await AppDatabase.instance.database;

    final stockRepository = AppDatabase.instance.groceryStockRepository!;
    final saleRepository = AppDatabase.instance.saleRepository!;
    final saleItemRepository = AppDatabase.instance.saleItemRepository!;
    final fundRepository = AppDatabase.instance.fundRepository!;

    final sale = Sale(
      receiptNumber: receiptNumber,
      customerId: customerId,
      customerName: customerName,
      totalPrice: totals.totalPrice,
      amountPayable: totals.amountPayable,
      amountPaid: amountPaid,
      changeAmount: totals.changeAmount,
      soldAt: soldAt ?? DateTime.now(),
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
        stockItem.copyWith(quantityInStock: stockItem.quantityInStock - item.quantity),
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
    );

    Fund? groceryFund;
    final funds = await fundRepository.getAll();
    for (final fund in funds) {
      if (fund.name == FundRepository.groceryCashName) {
        groceryFund = fund;
        break;
      }
    }

    if (groceryFund != null) {
      await fundRepository.update(groceryFund.copyWith(currentBalance: groceryFund.currentBalance + netCashCollected));
    }

    return createdSale;
  }
}
