import '../../../core/database/app_database.dart';
import '../data/models/expense.dart';

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  void validateExpenseInput({
    required double amount,
    required String personName,
    required String purpose,
  }) {
    if (amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    if (personName.trim().isEmpty) throw ArgumentError('Person name is required.');
    if (purpose.trim().isEmpty) throw ArgumentError('Purpose is required.');
  }

  Future<List<Expense>> getExpenses() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.expenseRepository!.getAll();
  }

  Future<Expense> addExpense({
    required int fundId,
    required double amount,
    required DateTime expenseDate,
    required String personName,
    required String purpose,
    String? details,
    String? notes,
  }) async {
    validateExpenseInput(amount: amount, personName: personName, purpose: purpose);
    await AppDatabase.instance.database;

    final fundRepository = AppDatabase.instance.fundRepository!;
    final fund = await fundRepository.getById(fundId);
    if (fund == null) throw ArgumentError('Selected fund was not found.');
    if (fund.currentBalance < amount) throw ArgumentError('Selected fund does not have enough balance.');

    await fundRepository.update(fund.copyWith(currentBalance: fund.currentBalance - amount));

    return AppDatabase.instance.expenseRepository!.create(
      Expense(
        fundId: fundId,
        amount: amount,
        expenseDate: expenseDate,
        personName: personName.trim(),
        purpose: purpose.trim(),
        details: details?.trim().isEmpty == true ? null : details?.trim(),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ),
    );
  }

  Future<void> updateExpense({
    required int id,
    required int fundId,
    required double amount,
    required DateTime expenseDate,
    required String personName,
    required String purpose,
    String? details,
    String? notes,
  }) async {
    validateExpenseInput(amount: amount, personName: personName, purpose: purpose);
    await AppDatabase.instance.database;

    final repository = AppDatabase.instance.expenseRepository!;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final existing = await repository.getById(id);
    if (existing == null) throw StateError('Expense was not found.');

    final previousFund = await fundRepository.getById(existing.fundId);
    if (previousFund == null) throw StateError('Previous fund was not found.');
    await fundRepository.update(previousFund.copyWith(currentBalance: previousFund.currentBalance + existing.amount));

    final newFund = await fundRepository.getById(fundId);
    if (newFund == null) throw ArgumentError('Selected fund was not found.');
    if (newFund.currentBalance < amount) throw ArgumentError('Selected fund does not have enough balance.');
    await fundRepository.update(newFund.copyWith(currentBalance: newFund.currentBalance - amount));

    await repository.update(
      existing.copyWith(
        fundId: fundId,
        amount: amount,
        expenseDate: expenseDate,
        personName: personName.trim(),
        purpose: purpose.trim(),
        details: details?.trim().isEmpty == true ? null : details?.trim(),
        notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      ),
    );
  }

  Future<void> deleteExpense(int id) async {
    await AppDatabase.instance.database;
    final repository = AppDatabase.instance.expenseRepository!;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final expense = await repository.getById(id);
    if (expense == null) throw StateError('Expense was not found.');

    final fund = await fundRepository.getById(expense.fundId);
    if (fund == null) throw StateError('Fund was not found.');

    await fundRepository.update(fund.copyWith(currentBalance: fund.currentBalance + expense.amount));
    await repository.delete(id);
  }
}
