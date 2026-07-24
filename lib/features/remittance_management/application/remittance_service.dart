import '../../../core/database/app_database.dart';
import '../../customer_management/application/customer_service.dart';
import '../../customer_management/data/models/customer.dart';
import '../../fund_management/data/models/fund.dart';
import '../data/models/remittance.dart';

class RemittanceService {
  RemittanceService._();
  static final RemittanceService instance = RemittanceService._();

  String getStatusLabel(RemittanceStatus status, {required RemittanceType remittanceType}) {
    if (remittanceType == RemittanceType.cashIn) {
      return 'Received by customer';
    }
    return status == RemittanceStatus.receivedByCustomer ? 'Received by customer' : 'Not received';
  }

  bool canEditStatus(RemittanceType remittanceType) => remittanceType == RemittanceType.cashOut;

  RemittanceStatus getInitialStatusForType(RemittanceType remittanceType) {
    if (remittanceType == RemittanceType.cashIn) {
      return RemittanceStatus.receivedByCustomer;
    }
    return RemittanceStatus.pending;
  }

  void validateRemittanceInput({
    required String referenceNumber,
    required double amount,
    required double charge,
  }) {
    if (referenceNumber.trim().isEmpty) throw ArgumentError('Reference number is required.');
    if (amount <= 0) throw ArgumentError('Amount must be greater than zero.');
    if (charge < 0) throw ArgumentError('Charge cannot be negative.');
  }

  Future<List<Remittance>> getRemittances() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.remittanceRepository!.getAll();
  }

  Future<Remittance> addRemittance({
    required int fundId,
    required RemittanceType remittanceType,
    required String referenceNumber,
    required double amount,
    required double charge,
    int? customerId,
    String? newCustomerName,
    String? newCustomerAddress,
    String? newCustomerContact,
    String? customerIdPicturePath,
    required RemittanceStatus remittanceStatus,
    String? notes,
  }) async {
    validateRemittanceInput(referenceNumber: referenceNumber, amount: amount, charge: charge);

    await AppDatabase.instance.database;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final fund = await fundRepository.getById(fundId);
    if (fund == null || fund.fundType != FundType.eCash) {
      throw ArgumentError('Only eCash funds can be used for remittance records.');
    }

    final remittanceCashFund = await fundRepository.getById(2);
    if (remittanceCashFund == null) {
      throw StateError('Remittance cash fund was not found.');
    }

    Customer? customer;
    if (customerId != null && customerId > 0) {
      customer = await CustomerService.instance.getCustomer(customerId);
      if (customer == null) throw ArgumentError('Selected customer was not found.');
    } else if ((newCustomerName?.trim().isNotEmpty ?? false) ||
        (newCustomerAddress?.trim().isNotEmpty ?? false) ||
        (newCustomerContact?.trim().isNotEmpty ?? false)) {
      customer = await CustomerService.instance.createCustomer(
        name: newCustomerName?.trim() ?? 'New customer',
        address: newCustomerAddress,
        contactNumber: newCustomerContact,
        idPicturePath: customerIdPicturePath,
      );
    }

    final effectiveRemittanceStatus = remittanceType == RemittanceType.cashIn
        ? RemittanceStatus.receivedByCustomer
        : remittanceStatus;

    final remittance = Remittance(
      fundId: fund.id!,
      remittanceType: remittanceType,
      referenceNumber: referenceNumber.trim(),
      amount: amount,
      charge: charge,
      processedAt: DateTime.now(),
      customerId: customer?.id,
      customerName: customer?.name,
      customerIdPicturePath: customer?.idPicturePath ?? customerIdPicturePath,
      processedBy: 'Local user',
      remittanceStatus: effectiveRemittanceStatus,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    );

    var updatedFundBalance = fund.currentBalance;
    var updatedCashFundBalance = remittanceCashFund.currentBalance;

    if (remittanceType == RemittanceType.cashIn) {
      updatedFundBalance -= amount;
      updatedCashFundBalance += amount + charge;
    } else {
      updatedFundBalance += amount;
      if (effectiveRemittanceStatus == RemittanceStatus.receivedByCustomer) {
        updatedCashFundBalance -= amount;
        updatedCashFundBalance += charge;
      }
    }

    await fundRepository.update(fund.copyWith(currentBalance: updatedFundBalance));
    await fundRepository.update(remittanceCashFund.copyWith(currentBalance: updatedCashFundBalance));

    return AppDatabase.instance.remittanceRepository!.create(remittance);
  }

  Future<Remittance> updateRemittance({
    required Remittance existingRemittance,
    required RemittanceType remittanceType,
    required String referenceNumber,
    required double amount,
    required double charge,
    int? customerId,
    String? customerIdPicturePath,
    required RemittanceStatus remittanceStatus,
    String? notes,
  }) async {
    validateRemittanceInput(referenceNumber: referenceNumber, amount: amount, charge: charge);

    await AppDatabase.instance.database;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final remittanceRepository = AppDatabase.instance.remittanceRepository!;
    final fund = await fundRepository.getById(existingRemittance.fundId);
    if (fund == null || fund.fundType != FundType.eCash) {
      throw ArgumentError('Only eCash funds can be used for remittance records.');
    }

    final remittanceCashFund = await fundRepository.getById(2);
    if (remittanceCashFund == null) {
      throw StateError('Remittance cash fund was not found.');
    }

    Customer? customer;
    if (customerId != null && customerId > 0) {
      customer = await CustomerService.instance.getCustomer(customerId);
      if (customer == null) throw ArgumentError('Selected customer was not found.');
    }

    var updatedFundBalance = fund.currentBalance;
    var updatedCashFundBalance = remittanceCashFund.currentBalance;

    if (existingRemittance.remittanceType == RemittanceType.cashIn) {
      updatedFundBalance += existingRemittance.amount;
      updatedCashFundBalance -= existingRemittance.amount + existingRemittance.charge;
    } else {
      updatedFundBalance -= existingRemittance.amount;
      if (existingRemittance.remittanceStatus == RemittanceStatus.receivedByCustomer) {
        updatedCashFundBalance += existingRemittance.amount;
        updatedCashFundBalance -= existingRemittance.charge;
      }
    }

    final effectiveRemittanceStatus = remittanceType == RemittanceType.cashIn
        ? RemittanceStatus.receivedByCustomer
        : remittanceStatus;

    if (remittanceType == RemittanceType.cashIn) {
      updatedFundBalance -= amount;
      updatedCashFundBalance += amount + charge;
    } else {
      updatedFundBalance += amount;
      if (effectiveRemittanceStatus == RemittanceStatus.receivedByCustomer) {
        updatedCashFundBalance -= amount;
        updatedCashFundBalance += charge;
      }
    }

    final updatedRemittance = existingRemittance.copyWith(
      fundId: fund.id!,
      remittanceType: remittanceType,
      referenceNumber: referenceNumber.trim(),
      amount: amount,
      charge: charge,
      customerId: customer?.id,
      customerName: customer?.name,
      customerIdPicturePath: customerIdPicturePath ?? customer?.idPicturePath ?? existingRemittance.customerIdPicturePath,
      editedBy: 'Local user',
      remittanceStatus: effectiveRemittanceStatus,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    );

    await fundRepository.update(fund.copyWith(currentBalance: updatedFundBalance));
    await fundRepository.update(remittanceCashFund.copyWith(currentBalance: updatedCashFundBalance));
    return remittanceRepository.update(updatedRemittance);
  }

  Future<void> deleteRemittance(int id) async {
    await AppDatabase.instance.database;
    final remittanceRepository = AppDatabase.instance.remittanceRepository!;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final remittance = await remittanceRepository.getById(id);

    if (remittance == null) throw StateError('Remittance was not found.');

    final remittanceCashFund = await fundRepository.getById(2);
    final remittanceFund = await fundRepository.getById(remittance.fundId);
    if (remittanceCashFund == null || remittanceFund == null) {
      throw StateError('Remittance funds were not found.');
    }

    var updatedFundBalance = remittanceFund.currentBalance;
    var updatedCashFundBalance = remittanceCashFund.currentBalance;

    if (remittance.remittanceType == RemittanceType.cashIn) {
      updatedCashFundBalance -= remittance.amount;
      updatedCashFundBalance -= remittance.charge;
      updatedFundBalance += remittance.amount;
    } else {
      if (remittance.remittanceStatus == RemittanceStatus.receivedByCustomer) {
        updatedCashFundBalance += remittance.amount;
        updatedCashFundBalance -= remittance.charge;
        updatedFundBalance -= remittance.amount;
      } else {
        updatedFundBalance -= remittance.amount;
      }
    }

    await fundRepository.update(remittanceFund.copyWith(currentBalance: updatedFundBalance));
    await fundRepository.update(remittanceCashFund.copyWith(currentBalance: updatedCashFundBalance));
    await remittanceRepository.delete(id);
  }
}
