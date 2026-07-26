import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../customer_management/data/models/customer_balance_payment.dart';
import '../../../fund_management/data/repositories/fund_repository.dart';
import '../../../sales_management/data/models/sale.dart';
import '../../../sales_management/application/sales_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardSummary> _summaryFuture;
  _PeriodFilter _selectedPeriod = _PeriodFilter.week;
  DateTime _selectedDate = DateTime.now().toLocal();
  final TextEditingController _minimumProfitController =
      TextEditingController(text: '1000');
  final FocusNode _targetFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
    _loadSavedTarget();
  }

  @override
  void dispose() {
    _minimumProfitController.dispose();
    _targetFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTarget() async {
    final savedTarget =
        await AppDatabase.instance.getDashboardTarget('daily_target_profit');
    if (!mounted) return;
    _minimumProfitController.text = savedTarget.toStringAsFixed(2);
  }

  Future<void> _saveTargetProfit() async {
    final parsedTarget = double.tryParse(_minimumProfitController.text) ?? 0;
    await AppDatabase.instance
        .saveDashboardTarget('daily_target_profit', parsedTarget);
    if (!mounted) return;
    setState(() {
      _summaryFuture = _loadSummary();
    });
  }

  Future<_DashboardSummary> _loadSummary() async {
    await AppDatabase.instance.database;

    final sales = await SalesService.instance.getSales();
    final saleItems = await AppDatabase.instance.saleItemRepository!.getAll();
    final remittances =
        await AppDatabase.instance.remittanceRepository!.getAll();
    final expenses = await AppDatabase.instance.expenseRepository!.getAll();
    final stockItems =
        await AppDatabase.instance.groceryStockRepository!.getAll();
    final funds = await AppDatabase.instance.fundRepository!.getAll();
    final customers = await AppDatabase.instance.customerRepository!.getAll();
    final customerBalancePayments =
        await AppDatabase.instance.customerBalancePaymentRepository!.getAll();

    final end = _periodEnd(_selectedDate);
    final start = _periodStart(end);

    final filteredSales = sales.where((sale) {
      final soldAt = sale.soldAt.toLocal();
      return !soldAt.isBefore(start) && !soldAt.isAfter(end);
    }).toList();

    final filteredRemittances = remittances.where((remittance) {
      final processedAt = remittance.processedAt?.toLocal();
      if (processedAt == null) return false;
      return !processedAt.isBefore(start) && !processedAt.isAfter(end);
    }).toList();

    final filteredExpenses = expenses.where((expense) {
      final expenseDay = DateTime(expense.expenseDate.year,
          expense.expenseDate.month, expense.expenseDate.day);
      return !expenseDay.isBefore(start) && !expenseDay.isAfter(end);
    }).toList();

    final filteredBalancePayments = customerBalancePayments.where((payment) {
      final paymentDate = payment.createdAt.toLocal();
      return !paymentDate.isBefore(start) && !paymentDate.isAfter(end);
    }).toList();

    final salesValue =
        filteredSales.fold<double>(0, (sum, sale) => sum + sale.amountPayable);
    final remittanceCharges = filteredRemittances.fold<double>(
        0, (sum, remittance) => sum + remittance.charge);
    final expensesValue = filteredExpenses.fold<double>(
        0, (sum, expense) => sum + expense.amount);
    final balancePaymentCash = calculateCollectedBalancePayments(
      payments: filteredBalancePayments,
      start: start,
      end: end,
    );

    final stockByName = {
      for (final item in stockItems) item.itemName.toLowerCase(): item
    };
    final stockByBarcode = {
      for (final item in stockItems) item.stockNumber.toLowerCase(): item
    };

    double groceryProfit = 0;
    double totalCostOfGoodsSold = 0;
    final itemQuantities = <String, int>{};
    for (final saleItem in saleItems) {
      final sale = filteredSales
          .where((entry) => entry.id == saleItem.saleId)
          .firstOrNull;
      if (sale == null) continue;
      final stock = stockByName[saleItem.itemName.toLowerCase()] ??
          stockByBarcode[saleItem.itemBarcode.toLowerCase()];
      if (stock == null) continue;
      final itemCost = saleItem.quantityBought * stock.capitalPrice;
      final itemProfit =
          saleItem.quantityBought * (saleItem.retailPrice - stock.capitalPrice);
      totalCostOfGoodsSold += itemCost;
      groceryProfit += itemProfit;
      itemQuantities[saleItem.itemName] =
          (itemQuantities[saleItem.itemName] ?? 0) + saleItem.quantityBought;
    }

    final topSellingEntry = itemQuantities.entries
        .fold<MapEntry<String, int>?>(null, (current, entry) {
      if (current == null || entry.value > current.value) {
        return entry;
      }
      return current;
    });

    final remittanceProfit = remittanceCharges;
    final remittanceCash = funds
        .where((fund) => fund.name == FundRepository.remittanceECashName)
        .fold<double>(0, (sum, fund) => sum + fund.currentBalance);
    final fundsValue =
        funds.fold<double>(0, (sum, fund) => sum + fund.currentBalance);
    final lowStockItems = stockItems
        .where((item) =>
            item.quantityInStock > 0 &&
            item.quantityInStock <= item.minimumAlertQuantity)
        .length;
    final outOfStockItems =
        stockItems.where((item) => item.quantityInStock <= 0).length;
    final totalStockQuantity =
        stockItems.fold<int>(0, (sum, item) => sum + item.quantityInStock);
    final expiredItems = stockItems
        .where((item) =>
            item.quantityInStock > 0 &&
            item.expirationDate != null &&
            item.expirationDate!.isBefore(end))
        .length;
    final expiringSoonItems = stockItems.where((item) {
      final expirationDate = item.expirationDate;
      return item.quantityInStock > 0 &&
          expirationDate != null &&
          !expirationDate.isBefore(end) &&
          expirationDate.difference(end).inDays <= 30;
    }).length;
    final customerBalance = calculateCustomerOutstandingBalance(
      sales: sales,
      payments: customerBalancePayments,
      asOf: end,
    );
    final grocerySalesWithBalancePayments = salesValue + balancePaymentCash;

    final dailyTarget = double.tryParse(_minimumProfitController.text) ?? 0;
    final dayProfit = _profitForPeriod(
      period: _PeriodFilter.day,
      anchorDate: end,
      allSales: sales,
      allRemittances: remittances,
      allExpenses: expenses,
      allSaleItems: saleItems,
      allStockItems: stockItems,
    );
    final weekProfit = _profitForPeriod(
      period: _PeriodFilter.week,
      anchorDate: end,
      allSales: sales,
      allRemittances: remittances,
      allExpenses: expenses,
      allSaleItems: saleItems,
      allStockItems: stockItems,
    );
    final monthProfit = _profitForPeriod(
      period: _PeriodFilter.month,
      anchorDate: end,
      allSales: sales,
      allRemittances: remittances,
      allExpenses: expenses,
      allSaleItems: saleItems,
      allStockItems: stockItems,
    );
    final yearProfit = _profitForPeriod(
      period: _PeriodFilter.year,
      anchorDate: end,
      allSales: sales,
      allRemittances: remittances,
      allExpenses: expenses,
      allSaleItems: saleItems,
      allStockItems: stockItems,
    );

    final trendPoints = _buildTrendPoints(
        start,
        end,
        filteredSales,
        filteredRemittances,
        filteredExpenses,
        filteredBalancePayments,
        saleItems,
        stockItems);
    final targetProfit = _minimumTarget();
    final currentProfit = calculateCurrentProfit(
      salesRevenue: salesValue,
      costOfGoodsSold: totalCostOfGoodsSold,
      remittanceProfit: remittanceProfit,
      expenses: expensesValue,
    );
    final alert = buildDashboardProfitAlert(currentProfit, targetProfit);

    return _DashboardSummary(
      periodLabel: _periodLabel,
      sales: grocerySalesWithBalancePayments,
      rawSales: salesValue,
      salesTransactions: filteredSales.length,
      averageTicketSize:
          filteredSales.isEmpty ? 0 : salesValue / filteredSales.length,
      groceryProfit: groceryProfit,
      grossProfitMargin:
          salesValue <= 0 ? 0 : (groceryProfit / salesValue) * 100,
      topSellingItemName: topSellingEntry?.key ?? 'No sales yet',
      topSellingQuantity: topSellingEntry?.value ?? 0,
      remittanceProfit: remittanceProfit,
      remittanceCash: remittanceCash,
      balancePaymentCash: balancePaymentCash,
      expenses: expensesValue,
      lowStockItems: lowStockItems,
      outOfStockItems: outOfStockItems,
      totalStockQuantity: totalStockQuantity,
      expiredItems: expiredItems,
      expiringSoonItems: expiringSoonItems,
      customerBalance: customerBalance,
      fundsValue: fundsValue,
      currentProfit: currentProfit,
      profitTrend: trendPoints.profit,
      minimumTarget: targetProfit,
      alertStatus: alert.status,
      alertMessage: alert.message,
      alertDifference: alert.differenceText,
      customersCount: customers.length,
      totalCostOfGoodsSold: totalCostOfGoodsSold,
      dayProfit: dayProfit,
      weekProfit: weekProfit,
      monthProfit: monthProfit,
      yearProfit: yearProfit,
      dailyTarget: dailyTarget,
    );
  }

  DateTime _periodEnd(DateTime now) =>
      DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  DateTime _periodStart(DateTime end) {
    switch (_selectedPeriod) {
      case _PeriodFilter.day:
        return DateTime(end.year, end.month, end.day);
      case _PeriodFilter.week:
        return end.subtract(const Duration(days: 6));
      case _PeriodFilter.month:
        return DateTime(end.year, end.month, 1);
      case _PeriodFilter.year:
        return DateTime(end.year, 1, 1);
    }
  }

  double _profitForPeriod({
    required _PeriodFilter period,
    required DateTime anchorDate,
    required List<dynamic> allSales,
    required List<dynamic> allRemittances,
    required List<dynamic> allExpenses,
    required List<dynamic> allSaleItems,
    required List<dynamic> allStockItems,
  }) {
    final end = DateTime(
        anchorDate.year, anchorDate.month, anchorDate.day, 23, 59, 59, 999);
    final start = _periodStartFor(period, end);

    final filteredSales = allSales.where((sale) {
      final soldAt = sale.soldAt.toLocal();
      return !soldAt.isBefore(start) && !soldAt.isAfter(end);
    }).toList();
    final filteredRemittances = allRemittances.where((remittance) {
      final processedAt = remittance.processedAt?.toLocal();
      if (processedAt == null) return false;
      return !processedAt.isBefore(start) && !processedAt.isAfter(end);
    }).toList();
    final filteredExpenses = allExpenses.where((expense) {
      final expenseDay = DateTime(expense.expenseDate.year,
          expense.expenseDate.month, expense.expenseDate.day);
      return !expenseDay.isBefore(start) && !expenseDay.isAfter(end);
    }).toList();

    final salesRevenue =
        filteredSales.fold<double>(0, (sum, sale) => sum + sale.amountPayable);
    final remittanceCharges = filteredRemittances.fold<double>(
        0, (sum, remittance) => sum + remittance.charge);
    final expensesValue = filteredExpenses.fold<double>(
        0, (sum, expense) => sum + expense.amount);

    final stockByName = {
      for (final item in allStockItems) item.itemName.toLowerCase(): item
    };
    final stockByBarcode = {
      for (final item in allStockItems) item.stockNumber.toLowerCase(): item
    };
    double costOfGoodsSold = 0;

    for (final saleItem in allSaleItems) {
      final sale = filteredSales
          .where((entry) => entry.id == saleItem.saleId)
          .firstOrNull;
      if (sale == null) continue;
      final stock = stockByName[saleItem.itemName.toLowerCase()] ??
          stockByBarcode[saleItem.itemBarcode.toLowerCase()];
      if (stock == null) continue;
      costOfGoodsSold += saleItem.quantityBought * stock.capitalPrice;
    }

    return calculateCurrentProfitValue(
      salesRevenue: salesRevenue,
      costOfGoodsSold: costOfGoodsSold,
      remittanceProfit: remittanceCharges,
      expenses: expensesValue,
    );
  }

  DateTime _periodStartFor(_PeriodFilter period, DateTime end) {
    switch (period) {
      case _PeriodFilter.day:
        return DateTime(end.year, end.month, end.day);
      case _PeriodFilter.week:
        return end.subtract(const Duration(days: 6));
      case _PeriodFilter.month:
        return DateTime(end.year, end.month, 1);
      case _PeriodFilter.year:
        return DateTime(end.year, 1, 1);
    }
  }

  Future<void> _pickDashboardDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;
    setState(() {
      _selectedDate =
          DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
      _summaryFuture = _loadSummary();
    });
  }

  _TrendPoints _buildTrendPoints(
    DateTime start,
    DateTime end,
    List<dynamic> sales,
    List<dynamic> remittances,
    List<dynamic> expenses,
    List<dynamic> balancePayments,
    List<dynamic> saleItems,
    List<dynamic> stockItems,
  ) {
    final intervals = <DateTime>[];
    switch (_selectedPeriod) {
      case _PeriodFilter.day:
        intervals.addAll(List.generate(
            6, (index) => end.subtract(Duration(hours: 4 * (5 - index)))));
        break;
      case _PeriodFilter.week:
        intervals.addAll(
            List.generate(7, (index) => start.add(Duration(days: index))));
        break;
      case _PeriodFilter.month:
        intervals.addAll(List.generate(
            6, (index) => DateTime(end.year, end.month, 1 + index * 5)));
        break;
      case _PeriodFilter.year:
        intervals.addAll(
            List.generate(12, (index) => DateTime(end.year, index + 1, 1)));
        break;
    }

    final profitTrend = intervals.map((day) {
      double profit = 0;
      for (final saleItem in saleItems) {
        final sale =
            sales.where((entry) => entry.id == saleItem.saleId).firstOrNull;
        if (sale == null) continue;
        if (_bucketFor(day, sale.soldAt.toLocal()) != day) continue;
        final stock = stockItems
            .where((entry) =>
                entry.itemName.toLowerCase() ==
                    saleItem.itemName.toLowerCase() ||
                entry.stockNumber.toLowerCase() ==
                    saleItem.itemBarcode.toLowerCase())
            .firstOrNull;
        if (stock == null) continue;
        profit += saleItem.quantityBought *
            (saleItem.retailPrice - stock.capitalPrice);
      }
      for (final remittance in remittances) {
        final processedAt = remittance.processedAt?.toLocal();
        if (processedAt != null && _bucketFor(day, processedAt) == day) {
          profit += remittance.charge;
        }
      }
      for (final expense in expenses) {
        final expenseDay = DateTime(expense.expenseDate.year,
            expense.expenseDate.month, expense.expenseDate.day);
        if (_bucketFor(day, expenseDay) == day) {
          profit -= expense.amount;
        }
      }
      for (final payment in balancePayments) {
        final paymentDate = payment.createdAt.toLocal();
        if (payment.paymentType == CustomerBalancePaymentType.payment &&
            _bucketFor(day, paymentDate) == day) {
          profit += payment.amount;
        }
      }
      return _ChartPoint(day: day, value: profit);
    }).toList();

    return _TrendPoints(profit: profitTrend);
  }

  DateTime _bucketFor(DateTime bucket, DateTime value) {
    switch (_selectedPeriod) {
      case _PeriodFilter.day:
        return DateTime(
            value.year, value.month, value.day, value.hour ~/ 4 * 4);
      case _PeriodFilter.week:
        return DateTime(value.year, value.month, value.day);
      case _PeriodFilter.month:
        return DateTime(value.year, value.month, value.day);
      case _PeriodFilter.year:
        return DateTime(value.year, value.month, 1);
    }
  }

  double _minimumTarget() {
    final rawValue = double.tryParse(_minimumProfitController.text) ?? 0;
    switch (_selectedPeriod) {
      case _PeriodFilter.day:
        return rawValue;
      case _PeriodFilter.week:
        return rawValue * 7;
      case _PeriodFilter.month:
        return rawValue * 30;
      case _PeriodFilter.year:
        return rawValue * 365;
    }
  }

  _DashboardProfitAlert buildDashboardProfitAlert(
          double currentProfit, double targetProfit) =>
      _buildDashboardProfitAlertHelper(currentProfit, targetProfit);

  double calculateCurrentProfit(
      {required double salesRevenue,
      required double costOfGoodsSold,
      required double remittanceProfit,
      required double expenses}) {
    return calculateCurrentProfitValue(
      salesRevenue: salesRevenue,
      costOfGoodsSold: costOfGoodsSold,
      remittanceProfit: remittanceProfit,
      expenses: expenses,
    );
  }

  String get _periodLabel {
    switch (_selectedPeriod) {
      case _PeriodFilter.day:
        return 'Today';
      case _PeriodFilter.week:
        return 'This week';
      case _PeriodFilter.month:
        return 'This month';
      case _PeriodFilter.year:
        return 'This year';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business dashboard')),
      body: FutureBuilder<_DashboardSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No dashboard data yet.'));
          }

          final summary = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _summaryFuture = _loadSummary();
              });
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfitAlertCard(summary),
                  const SizedBox(height: 16),
                  _buildFilterCard(),
                  const SizedBox(height: 16),
                  _buildMetricRow(
                    _buildMetricCard(
                      title: 'Grocery sales',
                      valueText: '₱${summary.sales.toStringAsFixed(2)}',
                      color: const Color(0xFF0F766E),
                      icon: Icons.point_of_sale_rounded,
                      detailText: 'Transactions: ${summary.salesTransactions}',
                      secondaryText:
                          'Includes ₱${summary.balancePaymentCash.toStringAsFixed(2)} balance payments',
                    ),
                    _buildMetricCard(
                      title: 'Grocery profit',
                      valueText: '₱${summary.groceryProfit.toStringAsFixed(2)}',
                      color: const Color(0xFF10B981),
                      icon: Icons.shopping_basket_rounded,
                      detailText:
                          'Margin: ${summary.grossProfitMargin.toStringAsFixed(1)}%',
                      secondaryText:
                          'Top: ${summary.topSellingItemName} (${summary.topSellingQuantity})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow(
                    _buildMetricCard(
                      title: 'Current remittance cash',
                      valueText:
                          '₱${summary.remittanceCash.toStringAsFixed(2)}',
                      color: const Color(0xFF0369A1),
                      icon: Icons.account_balance_wallet_rounded,
                      detailText: 'Remittance cash fund balance',
                      secondaryText: 'Current available amount',
                    ),
                    _buildMetricCard(
                      title: 'Collected charge',
                      valueText:
                          '₱${summary.remittanceProfit.toStringAsFixed(2)}',
                      color: const Color(0xFFF59E0B),
                      icon: Icons.attach_money_rounded,
                      detailText: 'Total remittance charges',
                      secondaryText: 'For ${summary.periodLabel.toLowerCase()}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow(
                    _buildMetricCard(
                      title: 'Expired',
                      valueText: summary.expiredItems.toString(),
                      color: const Color(0xFFDC2626),
                      icon: Icons.explicit_rounded,
                      detailText: 'With remaining quantity',
                      secondaryText: 'Immediate action needed',
                      isCount: true,
                    ),
                    _buildMetricCard(
                      title: 'Expiring soon',
                      valueText: summary.expiringSoonItems.toString(),
                      color: const Color(0xFFF59E0B),
                      icon: Icons.schedule_rounded,
                      detailText: 'With remaining quantity',
                      secondaryText: 'Review within 30 days',
                      isCount: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow(
                    _buildMetricCard(
                      title: 'Out of stock',
                      valueText: summary.outOfStockItems.toString(),
                      color: const Color(0xFFDC2626),
                      icon: Icons.remove_shopping_cart_rounded,
                      detailText: 'Items with zero stock',
                      secondaryText: 'Immediate attention',
                      isCount: true,
                    ),
                    _buildMetricCard(
                      title: 'Low stock',
                      valueText: summary.lowStockItems.toString(),
                      color: const Color(0xFF7C3AED),
                      icon: Icons.warning_amber_rounded,
                      detailText: 'Items below reorder point',
                      secondaryText: 'Needs restock soon',
                      isCount: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMetricRow(
                    _buildMetricCard(
                      title: 'Expenses',
                      valueText: '₱${summary.expenses.toStringAsFixed(2)}',
                      color: const Color(0xFFEF4444),
                      icon: Icons.receipt_long_rounded,
                      detailText: 'Tracked spending',
                      secondaryText: 'Cash leaving the store',
                    ),
                    _buildMetricCard(
                      title: 'Customer balance',
                      valueText:
                          '₱${summary.customerBalance.toStringAsFixed(2)}',
                      color: const Color(0xFF2563EB),
                      icon: Icons.people_alt_rounded,
                      detailText: 'Open balances from customers',
                      secondaryText:
                          '${summary.customersCount} customers tracked',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Profit trend'),
                  const SizedBox(height: 8),
                  _buildProfitTrendSummary(summary),
                  const SizedBox(height: 12),
                  _buildChartCard(
                      'Current period movement',
                      summary.profitTrend,
                      const Color(0xFF2563EB),
                      'Bucketed movement for ${summary.periodLabel.toLowerCase()}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfitAlertCard(_DashboardSummary summary) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                      summary.alertStatus == 'PROFITABLE'
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: summary.alertStatus == 'PROFITABLE'
                          ? Colors.green
                          : Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(summary.alertStatus,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 8),
              Text(summary.alertMessage, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              Text(summary.alertDifference,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(
                  'Current profit: ₱${summary.currentProfit.toStringAsFixed(2)} • Target: ₱${summary.minimumTarget.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      );

  Widget _buildFilterCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter period',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _PeriodFilter.values.map((period) {
                  final selected = period == _selectedPeriod;
                  return ChoiceChip(
                    label: Text(_periodName(period)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedPeriod = period;
                        _summaryFuture = _loadSummary();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: ${DateFormat('MMM d, y').format(_selectedDate)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDashboardDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                    label: const Text('Choose date'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                focusNode: _targetFocusNode,
                controller: _minimumProfitController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Daily target profit',
                  helperText: 'Tap Done or leave the field to save.',
                ),
                onEditingComplete: () async {
                  _targetFocusNode.unfocus();
                  await _saveTargetProfit();
                },
                onSubmitted: (_) async {
                  await _saveTargetProfit();
                },
                onTapOutside: (_) {
                  FocusScope.of(context).unfocus();
                  _saveTargetProfit();
                },
              ),
            ],
          ),
        ),
      );

  Widget _buildSectionTitle(String title) => Text(title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold));

  Widget _buildMetricRow(Widget left, Widget right) => Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );

  Widget _buildMetricCard(
          {required String title,
          required String valueText,
          required Color color,
          required IconData icon,
          required String detailText,
          String? secondaryText,
          bool isCount = false}) =>
      SizedBox(
        child: Card(
          elevation: 0,
          color: color.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(valueText,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color)),
                const SizedBox(height: 6),
                Text(detailText,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                if (secondaryText != null) ...[
                  const SizedBox(height: 4),
                  Text(secondaryText,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _buildProfitTrendSummary(_DashboardSummary summary) {
    final dayTarget = summary.dailyTarget;
    final weekTarget = summary.dailyTarget * 7;
    final monthTarget = summary.dailyTarget * 30;
    final yearTarget = summary.dailyTarget * 365;

    return Column(
      children: [
        _buildMetricRow(
          _buildProfitPeriodCard('Day', summary.dayProfit, dayTarget),
          _buildProfitPeriodCard('Week', summary.weekProfit, weekTarget),
        ),
        const SizedBox(height: 12),
        _buildMetricRow(
          _buildProfitPeriodCard('Month', summary.monthProfit, monthTarget),
          _buildProfitPeriodCard('Year', summary.yearProfit, yearTarget),
        ),
      ],
    );
  }

  Widget _buildProfitPeriodCard(String label, double profit, double target) {
    final color = _profitColor(profit, target);
    return Card(
      color: color.withValues(alpha: 0.12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('₱${profit.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text('Target: ₱${target.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Color _profitColor(double profit, double target) {
    if (target <= 0) {
      return profit > 0 ? const Color(0xFF16A34A) : const Color(0xFFF59E0B);
    }
    final ratio = profit / target;
    if (ratio < 0.7) {
      return const Color(0xFFDC2626);
    }
    if (ratio <= 1.1) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF16A34A);
  }

  Widget _buildChartCard(
          String title, List<_ChartPoint> points, Color color, String helper) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(helper,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: points.map((point) {
                    final maxValue = points.fold<double>(0,
                        (sum, entry) => entry.value > sum ? entry.value : sum);
                    final height = maxValue <= 0
                        ? 0.0
                        : ((point.value / maxValue) * 100)
                            .clamp(10, 100)
                            .toDouble();
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: height,
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.85),
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(10))),
                            ),
                            const SizedBox(height: 8),
                            Text(_labelForPoint(point.day),
                                style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );

  String _labelForPoint(DateTime day) {
    switch (_selectedPeriod) {
      case _PeriodFilter.day:
        return DateFormat('HH').format(day);
      case _PeriodFilter.week:
        return DateFormat('E').format(day);
      case _PeriodFilter.month:
        return DateFormat('d').format(day);
      case _PeriodFilter.year:
        return DateFormat('MMM').format(day);
    }
  }

  String _periodName(_PeriodFilter period) {
    switch (period) {
      case _PeriodFilter.day:
        return 'Day';
      case _PeriodFilter.week:
        return 'Week';
      case _PeriodFilter.month:
        return 'Month';
      case _PeriodFilter.year:
        return 'Year';
    }
  }
}

class _DashboardSummary {
  const _DashboardSummary({
    required this.periodLabel,
    required this.sales,
    required this.rawSales,
    required this.salesTransactions,
    required this.averageTicketSize,
    required this.groceryProfit,
    required this.grossProfitMargin,
    required this.topSellingItemName,
    required this.topSellingQuantity,
    required this.remittanceProfit,
    required this.remittanceCash,
    required this.balancePaymentCash,
    required this.expenses,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.totalStockQuantity,
    required this.expiredItems,
    required this.expiringSoonItems,
    required this.customerBalance,
    required this.fundsValue,
    required this.currentProfit,
    required this.profitTrend,
    required this.minimumTarget,
    required this.alertStatus,
    required this.alertMessage,
    required this.alertDifference,
    required this.customersCount,
    required this.totalCostOfGoodsSold,
    required this.dayProfit,
    required this.weekProfit,
    required this.monthProfit,
    required this.yearProfit,
    required this.dailyTarget,
  });

  final String periodLabel;
  final double sales;
  final double rawSales;
  final int salesTransactions;
  final double averageTicketSize;
  final double groceryProfit;
  final double grossProfitMargin;
  final String topSellingItemName;
  final int topSellingQuantity;
  final double remittanceProfit;
  final double remittanceCash;
  final double balancePaymentCash;
  final double expenses;
  final int lowStockItems;
  final int outOfStockItems;
  final int totalStockQuantity;
  final int expiredItems;
  final int expiringSoonItems;
  final double customerBalance;
  final double fundsValue;
  final double currentProfit;
  final List<_ChartPoint> profitTrend;
  final double minimumTarget;
  final String alertStatus;
  final String alertMessage;
  final String alertDifference;
  final int customersCount;
  final double totalCostOfGoodsSold;
  final double dayProfit;
  final double weekProfit;
  final double monthProfit;
  final double yearProfit;
  final double dailyTarget;
}

class _TrendPoints {
  const _TrendPoints({required this.profit});

  final List<_ChartPoint> profit;
}

double calculateCurrentProfitValue(
    {required double salesRevenue,
    required double costOfGoodsSold,
    required double remittanceProfit,
    required double expenses}) {
  return salesRevenue - costOfGoodsSold + remittanceProfit - expenses;
}

double calculateCollectedBalancePayments(
    {required List<CustomerBalancePayment> payments,
    required DateTime start,
    required DateTime end}) {
  return payments.where((payment) {
    final paymentDate = payment.createdAt.toLocal();
    return payment.paymentType == CustomerBalancePaymentType.payment &&
        !paymentDate.isBefore(start) &&
        !paymentDate.isAfter(end);
  }).fold<double>(0, (sum, payment) => sum + payment.amount);
}

double calculateCustomerOutstandingBalance(
    {required List<Sale> sales,
    required List<CustomerBalancePayment> payments,
    required DateTime asOf}) {
  final asOfEnd = DateTime(asOf.year, asOf.month, asOf.day, 23, 59, 59, 999);
  final creditedBalance = sales.where((sale) {
    final soldAt = sale.soldAt.toLocal();
    return sale.customerId != null && !soldAt.isAfter(asOfEnd);
  }).fold<double>(0, (sum, sale) => sum + sale.outstandingBalance);

  final paidBalance = payments.where((payment) {
    final paymentDate = payment.createdAt.toLocal();
    return payment.paymentType == CustomerBalancePaymentType.payment &&
        !paymentDate.isAfter(asOfEnd);
  }).fold<double>(0, (sum, payment) => sum + payment.amount);

  final outstanding = creditedBalance - paidBalance;
  return outstanding > 0 ? outstanding : 0;
}

class _DashboardProfitAlert {
  const _DashboardProfitAlert(
      {required this.status,
      required this.message,
      required this.differenceText});

  final String status;
  final String message;
  final String differenceText;
}

_DashboardProfitAlert _buildDashboardProfitAlertHelper(
    double currentProfit, double targetProfit) {
  final isProfitable = currentProfit >= targetProfit;
  final difference = currentProfit - targetProfit;
  final differenceText = difference >= 0
      ? 'You are ₱${difference.toStringAsFixed(2)} above target'
      : 'You are ₱${difference.abs().toStringAsFixed(2)} below target';

  return _DashboardProfitAlert(
    status: isProfitable ? 'PROFITABLE' : 'AT LOSS',
    message: isProfitable
        ? '✅ PROFITABLE: Store is gaining'
        : '❌ AT LOSS: Store is losing money',
    differenceText: differenceText,
  );
}

enum _PeriodFilter { day, week, month, year }

class _ChartPoint {
  const _ChartPoint({required this.day, required this.value});

  final DateTime day;
  final double value;
}
