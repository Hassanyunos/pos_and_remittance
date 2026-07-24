import '../../../core/database/app_database.dart';
import '../../auth/application/auth_service.dart';
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
      throw StateError('GroceryCash and Remittance-eCash cannot be deleted.');
    }
    await AppDatabase.instance.fundRepository!.delete(id);
  }

  // The database seeds these two funds first, so their IDs are stable and they
  // remain protected even if an owner later changes their display names.
  bool _isProtected(Fund fund) => fund.id == 1 || fund.id == 2;

  void _requireOwner() {
    if (!_isOwner) throw StateError('Only the owner can manage funds.');
  }
}
