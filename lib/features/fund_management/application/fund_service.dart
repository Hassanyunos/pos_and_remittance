import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../auth/application/auth_service.dart';
import '../../expense_management/application/expense_service.dart';
import '../data/models/fund.dart';

class FundService {
  FundService._();
  static final FundService instance = FundService._();

  bool get _isOwner => AuthService.instance.currentUser?.isOwner ?? false;

  Future<List<Fund>> getFunds() async {
    _requireOwner();
    await AppDatabase.instance.database;
    return AppDatabase.instance.fundRepository!.getAll();
  }

  Future<void> addFund({
    required String name,
    required double currentBalance,
    required FundType fundType,
  }) async {
    _requireOwner();
    if (name.trim().isEmpty) throw ArgumentError('Fund name is required.');
    await AppDatabase.instance.database;
    await AppDatabase.instance.fundRepository!.create(Fund(
      name: name.trim(),
      currentBalance: currentBalance,
      fundType: fundType,
    ));
  }

  Future<void> updateFund({
    required int id,
    required String name,
    required double currentBalance,
    required FundType fundType,
  }) async {
    _requireOwner();
    if (name.trim().isEmpty) throw ArgumentError('Fund name is required.');
    await AppDatabase.instance.database;
    final fund = await AppDatabase.instance.fundRepository!.getById(id);
    if (fund == null) throw StateError('Fund was not found.');
    await AppDatabase.instance.fundRepository!.update(fund.copyWith(
      name: name.trim(),
      currentBalance: currentBalance,
      fundType: fundType,
    ));
  }

  Future<void> deleteFund(int id) async {
    _requireOwner();
    await AppDatabase.instance.database;
    final fund = await AppDatabase.instance.fundRepository!.getById(id);
    if (fund == null) throw StateError('Fund was not found.');
    if (_isProtected(fund)) {
      throw StateError(
          'GroceryCash, Remittance-Cash, and LaundryCash cannot be deleted.');
    }
    await AppDatabase.instance.fundRepository!.delete(id);
  }

  Future<double> getTotalFundBalance() async {
    await AppDatabase.instance.database;
    final funds = await AppDatabase.instance.fundRepository!.getAll();
    return funds.fold<double>(0, (sum, fund) => sum + fund.currentBalance);
  }

  Future<double> getTotalGroceryCapital() async {
    await AppDatabase.instance.database;
    final groceryItems =
        await AppDatabase.instance.groceryStockRepository!.getAll();
    return groceryItems.fold<double>(
        0, (sum, item) => sum + item.capitalPrice * item.quantityInStock);
  }

  Future<double> getCurrentZakahAmount({
    required double goldPricePerGram,
    required double silverPricePerGram,
  }) async {
    await AppDatabase.instance.database;
    final totalFunds = await getTotalFundBalance();
    final totalGroceryCapital = await getTotalGroceryCapital();
    final totalAssets = totalFunds + totalGroceryCapital;
    return calculateZakahAmount(
      totalAssets: totalAssets,
      goldPricePerGram: goldPricePerGram,
      silverPricePerGram: silverPricePerGram,
    );
  }

  Future<DateTime?> getLastZakahDate() async {
    await AppDatabase.instance.database;
    final expenses = await AppDatabase.instance.expenseRepository!.getAll();
    for (final expense in expenses
        .where((item) => item.purpose.toLowerCase() == 'zakat')
        .toList()) {
      return expense.expenseDate;
    }
    return null;
  }

  double calculateZakahAmount({
    required double totalAssets,
    required double goldPricePerGram,
    required double silverPricePerGram,
  }) {
    final nisab = math.max(85 * goldPricePerGram, 595 * silverPricePerGram);
    if (totalAssets < nisab) return 0;
    return totalAssets * 0.025;
  }

  Future<String> getCurrentZakatEligibilityMessage({
    required double goldPricePerGram,
    required double silverPricePerGram,
  }) async {
    await AppDatabase.instance.database;
    final totalFunds = await getTotalFundBalance();
    final totalGroceryCapital = await getTotalGroceryCapital();
    final totalAssets = totalFunds + totalGroceryCapital;
    final lastZakahDate = await getLastZakahDate();

    return validateZakatEligibility(
      totalAssets: totalAssets,
      goldPricePerGram: goldPricePerGram,
      silverPricePerGram: silverPricePerGram,
      lastZakahDate: lastZakahDate,
    );
  }

  String validateZakatEligibility({
    required double totalAssets,
    required double goldPricePerGram,
    required double silverPricePerGram,
    DateTime? lastZakahDate,
  }) {
    final nisab = math.max(85 * goldPricePerGram, 595 * silverPricePerGram);
    if (totalAssets < nisab) {
      return 'Zakat cannot be taken because your wealth is below the nisab threshold of ${_formatCurrency(nisab)}.';
    }

    if (lastZakahDate != null &&
        DateTime.now().difference(lastZakahDate).inDays < 354) {
      return 'Zakat cannot be taken again yet because it is only due once every year.';
    }

    return '';
  }

  Future<void> takeZakah({
    required double goldPricePerGram,
    required double silverPricePerGram,
    required int fundId,
  }) async {
    _requireOwner();
    await AppDatabase.instance.database;

    final lastZakahDate = await getLastZakahDate();
    final totalFunds = await getTotalFundBalance();
    final totalGroceryCapital = await getTotalGroceryCapital();
    final totalAssets = totalFunds + totalGroceryCapital;
    final eligibilityMessage = validateZakatEligibility(
      totalAssets: totalAssets,
      goldPricePerGram: goldPricePerGram,
      silverPricePerGram: silverPricePerGram,
      lastZakahDate: lastZakahDate,
    );

    if (eligibilityMessage.isNotEmpty) {
      throw StateError(eligibilityMessage);
    }

    final amount = await getCurrentZakahAmount(
      goldPricePerGram: goldPricePerGram,
      silverPricePerGram: silverPricePerGram,
    );

    if (amount <= 0) {
      throw StateError('The total assets do not meet the nisab.');
    }

    final fund = await AppDatabase.instance.fundRepository!.getById(fundId);
    if (fund == null) throw StateError('Selected fund not found.');

    await ExpenseService.instance.addExpense(
      fundId: fund.id!,
      amount: amount,
      expenseDate: DateTime.now(),
      personName: 'Owner',
      purpose: 'Zakat',
      details: 'Zakat paid from total funds and grocery capital',
      notes: 'Auto-generated zakat expense',
    );
  }

  // The database seeds these two funds first, so their IDs are stable and they
  // remain protected even if an owner later changes their display names.
  bool _isProtected(Fund fund) => fund.id == 1 || fund.id == 2 || fund.id == 3;

  String _formatCurrency(double amount) =>
      NumberFormat.currency(symbol: '₱').format(amount);

  void _requireOwner() {
    if (!_isOwner) throw StateError('Only the owner can manage funds.');
  }
}
