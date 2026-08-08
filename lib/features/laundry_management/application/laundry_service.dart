import '../../../core/database/app_database.dart';
import '../../customer_management/data/models/customer_balance_payment.dart';
import '../../fund_management/data/models/fund.dart';
import '../../fund_management/data/repositories/fund_repository.dart';
import '../../laundry_stock_management/data/models/laundry_stock_item.dart';
import '../data/models/laundry_order.dart';

class LaundryService {
  LaundryService._();
  static final LaundryService instance = LaundryService._();

  double getOutstandingBalance(LaundryOrder order) {
    final outstanding = order.amountPayable - order.amountPaid;
    return outstanding > 0 ? outstanding : 0;
  }

  String getStatusLabel(LaundryOrderStatus status) {
    return switch (status) {
      LaundryOrderStatus.pending => 'Pending',
      LaundryOrderStatus.inProgress => 'In progress',
      LaundryOrderStatus.readyForPickup => 'Ready for pickup',
      LaundryOrderStatus.pickedUp => 'Picked up',
    };
  }

  Future<List<LaundryOrder>> getOrders() async {
    await AppDatabase.instance.database;
    return AppDatabase.instance.laundryOrderRepository!.getAll();
  }

  Future<double> getOutstandingBalanceForCustomer(int customerId) async {
    final orders = await getOrders();
    return orders
        .where((order) => order.customerId == customerId)
        .fold<double>(0, (sum, order) => sum + getOutstandingBalance(order));
  }

  Future<LaundryOrder> addOrder({
    int? customerId,
    required bool isWalkIn,
    required String customerName,
    String? customerContact,
    required double weightKg,
    required int clothesCount,
    required double laundryBaseAmount,
    required int? serviceId,
    required String serviceName,
    required List<LaundryStockItem> serviceAddOns,
    required List<LaundryStockItem> paidAddOns,
    required double amountPaid,
    required LaundryOrderStatus status,
    String? itemImagePath,
    String? pickupProofImagePath,
    String? notes,
  }) async {
    _validateOrderInput(
      customerId: customerId,
      isWalkIn: isWalkIn,
      customerName: customerName,
      weightKg: weightKg,
      clothesCount: clothesCount,
      laundryBaseAmount: laundryBaseAmount,
      serviceName: serviceName,
      paidAddOns: paidAddOns,
      amountPaid: amountPaid,
      status: status,
      pickupProofImagePath: pickupProofImagePath,
    );

    await AppDatabase.instance.database;
    final fundRepository = AppDatabase.instance.fundRepository!;
    final laundryFund = await _getLaundryCashFund(fundRepository);

    final computed = _computeTotals(
      laundryBaseAmount: laundryBaseAmount,
      paidAddOns: paidAddOns,
      amountPaid: amountPaid,
    );

    await _deductStockQuantities(
      serviceAddOns: serviceAddOns,
      paidAddOns: paidAddOns,
    );

    final now = DateTime.now();
    final order = LaundryOrder(
      referenceNumber: _generateReference(),
      customerId: isWalkIn ? null : customerId,
      isWalkIn: isWalkIn,
      customerName: customerName.trim(),
      customerContact: customerContact?.trim().isEmpty == true
          ? null
          : customerContact?.trim(),
      weightKg: weightKg,
      clothesCount: clothesCount,
      laundryBaseAmount: laundryBaseAmount,
      serviceId: serviceId,
      serviceName: serviceName.trim(),
      serviceAddOns: _buildAddOnNames(serviceAddOns),
      serviceAddOnItemIds: _buildAddOnIds(serviceAddOns),
      addOns: _buildAddOnNames(paidAddOns),
      addOnItemIds: _buildAddOnIds(paidAddOns),
      paidAddOns: _buildAddOnNames(paidAddOns),
      paidAddOnItemIds: _buildAddOnIds(paidAddOns),
      addOnTotal: computed.addOnTotal,
      amountPayable: computed.totalDue,
      amountPaid: amountPaid,
      changeAmount: computed.changeAmount,
      status: status,
      itemImagePath:
          itemImagePath?.trim().isEmpty == true ? null : itemImagePath?.trim(),
      pickupProofImagePath: pickupProofImagePath?.trim().isEmpty == true
          ? null
          : pickupProofImagePath?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final createdOrder =
        await AppDatabase.instance.laundryOrderRepository!.create(order);

    await fundRepository.update(laundryFund.copyWith(
        currentBalance: laundryFund.currentBalance + createdOrder.netReceived));
    await _applyCustomerOutstandingOnCreate(
      order: createdOrder,
      outstandingBalance: _outstandingBalanceForOrder(createdOrder),
    );
    return createdOrder;
  }

  Future<LaundryOrder> updateOrder({
    required int id,
    int? customerId,
    required bool isWalkIn,
    required String customerName,
    String? customerContact,
    required double weightKg,
    required int clothesCount,
    required double laundryBaseAmount,
    required int? serviceId,
    required String serviceName,
    required List<LaundryStockItem> serviceAddOns,
    required List<LaundryStockItem> paidAddOns,
    required double amountPaid,
    required LaundryOrderStatus status,
    String? itemImagePath,
    String? pickupProofImagePath,
    String? notes,
  }) async {
    _validateOrderInput(
      customerId: customerId,
      isWalkIn: isWalkIn,
      customerName: customerName,
      weightKg: weightKg,
      clothesCount: clothesCount,
      laundryBaseAmount: laundryBaseAmount,
      serviceName: serviceName,
      paidAddOns: paidAddOns,
      amountPaid: amountPaid,
      status: status,
      pickupProofImagePath: pickupProofImagePath,
    );

    await AppDatabase.instance.database;
    final orderRepository = AppDatabase.instance.laundryOrderRepository!;
    final existing = await orderRepository.getById(id);
    if (existing == null) throw StateError('Laundry order was not found.');

    final fundRepository = AppDatabase.instance.fundRepository!;
    final laundryFund = await _getLaundryCashFund(fundRepository);

    final computed = _computeTotals(
      laundryBaseAmount: laundryBaseAmount,
      paidAddOns: paidAddOns,
      amountPaid: amountPaid,
    );

    final updated = existing.copyWith(
      customerId: isWalkIn ? null : customerId,
      isWalkIn: isWalkIn,
      customerName: customerName.trim(),
      customerContact: customerContact?.trim().isEmpty == true
          ? null
          : customerContact?.trim(),
      weightKg: weightKg,
      clothesCount: clothesCount,
      laundryBaseAmount: laundryBaseAmount,
      serviceId: serviceId,
      serviceName: serviceName.trim(),
      serviceAddOns: _buildAddOnNames(serviceAddOns),
      serviceAddOnItemIds: _buildAddOnIds(serviceAddOns),
      addOns: _buildAddOnNames(paidAddOns),
      addOnItemIds: _buildAddOnIds(paidAddOns),
      paidAddOns: _buildAddOnNames(paidAddOns),
      paidAddOnItemIds: _buildAddOnIds(paidAddOns),
      addOnTotal: computed.addOnTotal,
      amountPayable: computed.totalDue,
      amountPaid: amountPaid,
      changeAmount: computed.changeAmount,
      status: status,
      itemImagePath:
          itemImagePath?.trim().isEmpty == true ? null : itemImagePath?.trim(),
      pickupProofImagePath: pickupProofImagePath?.trim().isEmpty == true
          ? null
          : pickupProofImagePath?.trim(),
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      updatedAt: DateTime.now(),
    );

    final adjustedBalance =
        laundryFund.currentBalance - existing.netReceived + updated.netReceived;
    if (adjustedBalance < 0) {
      throw ArgumentError('This update would make LaundryCash negative.');
    }

    await fundRepository
        .update(laundryFund.copyWith(currentBalance: adjustedBalance));
    await _reconcileCustomerOutstandingOnUpdate(
      previous: existing,
      next: updated,
    );
    return orderRepository.update(updated);
  }

  Future<void> deleteOrder(int id) async {
    await AppDatabase.instance.database;
    final orderRepository = AppDatabase.instance.laundryOrderRepository!;
    final existing = await orderRepository.getById(id);
    if (existing == null) throw StateError('Laundry order was not found.');

    final fundRepository = AppDatabase.instance.fundRepository!;
    final laundryFund = await _getLaundryCashFund(fundRepository);
    final adjustedBalance = laundryFund.currentBalance - existing.netReceived;
    if (adjustedBalance < 0) {
      throw ArgumentError(
          'Cannot delete this order because LaundryCash would be negative.');
    }

    await fundRepository
        .update(laundryFund.copyWith(currentBalance: adjustedBalance));
    await _revertCustomerOutstandingOnDelete(existing);
    await orderRepository.delete(id);
  }

  Future<LaundryOrder> recordBalancePayment({
    required int orderId,
    required double paymentAmount,
    String? note,
  }) async {
    if (paymentAmount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    await AppDatabase.instance.database;
    final orderRepository = AppDatabase.instance.laundryOrderRepository!;
    final order = await orderRepository.getById(orderId);
    if (order == null) {
      throw StateError('Laundry order was not found.');
    }

    final outstanding = getOutstandingBalance(order);
    if (outstanding <= 0) {
      throw ArgumentError('This order has no remaining balance.');
    }
    if (paymentAmount > outstanding) {
      throw ArgumentError(
        'Payment cannot exceed remaining balance of P ${outstanding.toStringAsFixed(2)}.',
      );
    }

    final newAmountPaid = order.amountPaid + paymentAmount;
    final updated = order.copyWith(
      amountPaid: newAmountPaid,
      changeAmount: 0,
      updatedAt: DateTime.now(),
    );

    final fundRepository = AppDatabase.instance.fundRepository!;
    final laundryFund = await _getLaundryCashFund(fundRepository);
    await fundRepository.update(
      laundryFund.copyWith(
        currentBalance: laundryFund.currentBalance + paymentAmount,
      ),
    );

    final customerId = order.customerId;
    if (customerId != null) {
      final customerRepository = AppDatabase.instance.customerRepository!;
      final customer = await customerRepository.getById(customerId);
      if (customer != null) {
        final normalizedNote = note?.trim();
        final nextBalance = customer.currentBalance - paymentAmount;
        await customerRepository.update(
          customer.copyWith(currentBalance: nextBalance > 0 ? nextBalance : 0),
        );
        final paymentRepository =
            AppDatabase.instance.customerBalancePaymentRepository!;
        await paymentRepository.create(
          CustomerBalancePayment(
            customerId: customerId,
            laundryOrderId: order.id,
            amount: paymentAmount,
            paymentType: CustomerBalancePaymentType.payment,
            source: CustomerBalancePaymentSource.laundry,
            note: normalizedNote == null || normalizedNote.isEmpty
                ? 'Laundry balance payment for ${order.referenceNumber}'
                : normalizedNote,
            createdAt: DateTime.now(),
          ),
        );
      }
    }

    return orderRepository.update(updated);
  }

  Future<void> recordCustomerLaundryBalancePayment({
    required int customerId,
    required double paymentAmount,
    String? note,
  }) async {
    if (paymentAmount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final orders = await getOrders();
    final outstandingOrders = orders
        .where((order) => order.customerId == customerId)
        .where((order) => getOutstandingBalance(order) > 0)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final totalOutstanding = outstandingOrders.fold<double>(
      0,
      (sum, order) => sum + getOutstandingBalance(order),
    );
    if (totalOutstanding <= 0) {
      throw ArgumentError('This customer has no remaining laundry balance.');
    }
    if (paymentAmount > totalOutstanding) {
      throw ArgumentError(
        'Payment cannot exceed remaining laundry balance of P ${totalOutstanding.toStringAsFixed(2)}.',
      );
    }

    var remaining = paymentAmount;
    for (final order in outstandingOrders) {
      if (remaining <= 0) break;
      final orderOutstanding = getOutstandingBalance(order);
      if (orderOutstanding <= 0) continue;
      final allocation =
          remaining < orderOutstanding ? remaining : orderOutstanding;
      await recordBalancePayment(
        orderId: order.id!,
        paymentAmount: allocation,
        note: note,
      );
      remaining -= allocation;
    }
  }

  double _outstandingBalanceForOrder(LaundryOrder order) {
    return getOutstandingBalance(order);
  }

  Future<void> _applyCustomerOutstandingOnCreate({
    required LaundryOrder order,
    required double outstandingBalance,
  }) async {
    final customerId = order.customerId;
    if (customerId == null || outstandingBalance <= 0) return;
    final customerRepository = AppDatabase.instance.customerRepository!;
    final customer = await customerRepository.getById(customerId);
    if (customer == null) return;
    await customerRepository.update(
      customer.copyWith(
        currentBalance: customer.currentBalance + outstandingBalance,
      ),
    );

    final paymentRepository =
        AppDatabase.instance.customerBalancePaymentRepository!;
    await paymentRepository.create(
      CustomerBalancePayment(
        customerId: customerId,
        laundryOrderId: order.id,
        amount: outstandingBalance,
        paymentType: CustomerBalancePaymentType.credit,
        source: CustomerBalancePaymentSource.laundry,
        note: 'Laundry balance carried from order ${order.referenceNumber}',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _reconcileCustomerOutstandingOnUpdate({
    required LaundryOrder previous,
    required LaundryOrder next,
  }) async {
    final customerRepository = AppDatabase.instance.customerRepository!;

    final previousOutstanding = _outstandingBalanceForOrder(previous);
    if (previous.customerId != null && previousOutstanding > 0) {
      final previousCustomer =
          await customerRepository.getById(previous.customerId!);
      if (previousCustomer != null) {
        final updatedBalance =
            previousCustomer.currentBalance - previousOutstanding;
        await customerRepository.update(
          previousCustomer.copyWith(
            currentBalance: updatedBalance > 0 ? updatedBalance : 0,
          ),
        );
      }
    }

    final nextOutstanding = _outstandingBalanceForOrder(next);
    if (next.customerId != null && nextOutstanding > 0) {
      final nextCustomer = await customerRepository.getById(next.customerId!);
      if (nextCustomer != null) {
        await customerRepository.update(
          nextCustomer.copyWith(
            currentBalance: nextCustomer.currentBalance + nextOutstanding,
          ),
        );
      }
    }
  }

  Future<void> _revertCustomerOutstandingOnDelete(LaundryOrder order) async {
    final customerId = order.customerId;
    final outstanding = _outstandingBalanceForOrder(order);
    if (customerId == null || outstanding <= 0) return;

    final customerRepository = AppDatabase.instance.customerRepository!;
    final customer = await customerRepository.getById(customerId);
    if (customer == null) return;

    final updatedBalance = customer.currentBalance - outstanding;
    await customerRepository.update(
      customer.copyWith(
          currentBalance: updatedBalance > 0 ? updatedBalance : 0),
    );
  }

  Future<Fund> _getLaundryCashFund(FundRepository fundRepository) async {
    final funds = await fundRepository.getAll();
    final matches = funds.where((fund) =>
        fund.name.toLowerCase() ==
        FundRepository.laundryCashName.toLowerCase());
    if (matches.isEmpty) {
      throw StateError('LaundryCash fund was not found.');
    }
    return matches.first;
  }

  void _validateOrderInput({
    required int? customerId,
    required bool isWalkIn,
    required String customerName,
    required double weightKg,
    required int clothesCount,
    required double laundryBaseAmount,
    required String serviceName,
    required List<LaundryStockItem> paidAddOns,
    required double amountPaid,
    required LaundryOrderStatus status,
    required String? pickupProofImagePath,
  }) {
    if (!isWalkIn && customerId == null) {
      throw ArgumentError(
          'Please select an existing customer or choose walk-in.');
    }
    if (customerName.trim().isEmpty) {
      throw ArgumentError('Customer name is required.');
    }
    if (weightKg < 0) {
      throw ArgumentError('Weight cannot be negative.');
    }
    if (clothesCount < 0) {
      throw ArgumentError('Clothes count cannot be negative.');
    }
    if (laundryBaseAmount < 0) {
      throw ArgumentError('Laundry amount cannot be negative.');
    }
    if (serviceName.trim().isEmpty) {
      throw ArgumentError('Please select a laundry service.');
    }
    if (amountPaid < 0) {
      throw ArgumentError('Amount paid cannot be negative.');
    }
    final computed = _computeTotals(
      laundryBaseAmount: laundryBaseAmount,
      paidAddOns: paidAddOns,
      amountPaid: amountPaid,
    );
    if (computed.totalDue <= 0) {
      throw ArgumentError('Total amount due must be greater than zero.');
    }
    if (status == LaundryOrderStatus.pickedUp &&
        (pickupProofImagePath == null || pickupProofImagePath.trim().isEmpty)) {
      throw ArgumentError(
          'Pickup proof image is required when status is picked up.');
    }
  }

  String _generateReference() {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'LND-$stamp';
  }

  _ComputedTotals _computeTotals({
    required double laundryBaseAmount,
    required List<LaundryStockItem> paidAddOns,
    required double amountPaid,
  }) {
    final addOnTotal = paidAddOns.fold<double>(
      0,
      (sum, addOn) => sum + addOn.retailPrice,
    );
    final totalDue = laundryBaseAmount + addOnTotal;
    final changeAmount =
        (amountPaid - totalDue) > 0 ? (amountPaid - totalDue) : 0.0;
    return _ComputedTotals(
      addOnTotal: addOnTotal,
      totalDue: totalDue,
      changeAmount: changeAmount,
    );
  }

  String? _buildAddOnNames(List<LaundryStockItem> addOns) {
    if (addOns.isEmpty) return null;
    return addOns.map((addOn) => addOn.itemName).join(', ');
  }

  String? _buildAddOnIds(List<LaundryStockItem> addOns) {
    if (addOns.isEmpty) return null;
    return addOns
        .where((addOn) => addOn.id != null)
        .map((addOn) => addOn.id.toString())
        .join(',');
  }

  Future<void> _deductStockQuantities({
    required List<LaundryStockItem> serviceAddOns,
    required List<LaundryStockItem> paidAddOns,
  }) async {
    final repository = AppDatabase.instance.laundryStockRepository!;
    final usageByItemId = <int, int>{};

    for (final item in [...serviceAddOns, ...paidAddOns]) {
      final itemId = item.id;
      if (itemId == null) continue;
      usageByItemId[itemId] = (usageByItemId[itemId] ?? 0) + 1;
    }

    for (final entry in usageByItemId.entries) {
      final stockItem = await repository.getById(entry.key);
      if (stockItem == null) {
        throw StateError('Laundry stock item was not found.');
      }
      if (stockItem.quantityInStock < entry.value) {
        throw ArgumentError(
          'Insufficient stock for ${stockItem.itemName}. Available: ${stockItem.quantityInStock}, needed: ${entry.value}.',
        );
      }
    }

    for (final entry in usageByItemId.entries) {
      final stockItem = await repository.getById(entry.key);
      if (stockItem == null) continue;
      await repository.update(
        stockItem.copyWith(
            quantityInStock: stockItem.quantityInStock - entry.value),
      );
    }
  }
}

class _ComputedTotals {
  const _ComputedTotals({
    required this.addOnTotal,
    required this.totalDue,
    required this.changeAmount,
  });

  final double addOnTotal;
  final double totalDue;
  final double changeAmount;
}
