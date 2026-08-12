import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../customer_management/data/models/customer_balance_payment.dart';
import '../../../expense_management/data/models/expense.dart';
import '../../../sales_management/data/models/sale_item.dart';
import '../../../sales_management/data/models/sale.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<_DashboardSummary> _summaryFuture;
  _PeriodFilter _selectedPeriod = _PeriodFilter.month;
  DateTime _selectedDate = DateTime.now().toLocal();

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadSummary();
  }

  Future<_DashboardSummary> _loadSummary() async {
    await AppDatabase.instance.database;

    final sales = await AppDatabase.instance.saleRepository!.getAll();
    final saleItems = await AppDatabase.instance.saleItemRepository!.getAll();
    final groceryStocks =
        await AppDatabase.instance.groceryStockRepository!.getAll();
    final laundryOrders =
        await AppDatabase.instance.laundryOrderRepository!.getAll();
    final expenses = await AppDatabase.instance.expenseRepository!.getAll();
    final remittances =
        await AppDatabase.instance.remittanceRepository!.getAll();
    final balancePayments =
        await AppDatabase.instance.customerBalancePaymentRepository!.getAll();

    final currentRange = _rangeForPeriod(_selectedPeriod, _selectedDate);

    final topExpenseEntities = _buildTopExpenseEntities(
      expenses: expenses,
      range: currentRange,
    );

    final salesInRange =
        sales.where((sale) => _within(sale.soldAt, currentRange)).toList();
    final saleIdsInRange =
        salesInRange.map((sale) => sale.id).whereType<int>().toSet();

    final groceryPaidSales = salesInRange.fold<double>(
      0,
      (sum, sale) => sum + (sale.amountPaid - sale.changeAmount),
    );
    final groceryProfit = _computeGroceryProfit(
      saleItems: saleItems,
      saleIdsInRange: saleIdsInRange,
      groceryStocks: groceryStocks,
    );

    final laundrySales = laundryOrders.where((entry) {
      return _within(entry.createdAt, currentRange);
    }).fold<double>(0, (sum, entry) => sum + entry.amountPayable);

    final remittanceChargesCollected = remittances.where((entry) {
      final processedAt = entry.processedAt;
      if (processedAt == null) return false;
      return _within(processedAt, currentRange);
    }).fold<double>(0, (sum, entry) => sum + entry.charge);

    final paidLaundryBalance = balancePayments.where((payment) {
      return payment.paymentType == CustomerBalancePaymentType.payment &&
          payment.source == CustomerBalancePaymentSource.laundry &&
          _within(payment.createdAt, currentRange);
    }).fold<double>(0, (sum, payment) => sum + payment.amount);

    final paidGroceryBalance = balancePayments.where((payment) {
      return payment.paymentType == CustomerBalancePaymentType.payment &&
          payment.source == CustomerBalancePaymentSource.grocery &&
          _within(payment.createdAt, currentRange);
    }).fold<double>(0, (sum, payment) => sum + payment.amount);

    final totalUnpaidGroceryBalance = _calculateOutstandingBySource(
      payments: balancePayments,
      source: CustomerBalancePaymentSource.grocery,
    );
    final totalUnpaidLaundryBalance = laundryOrders.fold<double>(0, (sum, order) {
      final outstanding = order.amountPayable - order.amountPaid;
      return sum + (outstanding > 0 ? outstanding : 0);
    });

    return _DashboardSummary(
      periodLabel: _periodLabel(_selectedPeriod),
      rangeLabel: _rangeLabel(currentRange.start, currentRange.end),
      grocerySalesPaid: groceryPaidSales,
      grocerySalesProfit: groceryProfit,
      laundrySales: laundrySales,
      remittanceChargesCollected: remittanceChargesCollected,
      paidLaundryBalance: paidLaundryBalance,
      paidGroceryBalance: paidGroceryBalance,
      totalUnpaidGroceryBalance: totalUnpaidGroceryBalance,
      totalUnpaidLaundryBalance: totalUnpaidLaundryBalance,
      topExpenseEntities: topExpenseEntities,
    );
  }

  double _calculateOutstandingBySource({
    required List<CustomerBalancePayment> payments,
    required CustomerBalancePaymentSource source,
  }) {
    var credited = 0.0;
    var paid = 0.0;
    for (final payment in payments) {
      if (payment.source != source) continue;
      if (payment.paymentType == CustomerBalancePaymentType.credit) {
        credited += payment.amount;
      } else if (payment.paymentType == CustomerBalancePaymentType.payment) {
        paid += payment.amount;
      }
    }
    final outstanding = credited - paid;
    return outstanding > 0 ? outstanding : 0;
  }

  double _computeGroceryProfit({
    required List<SaleItem> saleItems,
    required Set<int> saleIdsInRange,
    required List<dynamic> groceryStocks,
  }) {
    final capitalByStockNumber = <String, double>{};
    final capitalByItemName = <String, double>{};
    for (final stock in groceryStocks) {
      final stockNumber = (stock.stockNumber as String?)?.trim() ?? '';
      final itemName = (stock.itemName as String?)?.trim().toLowerCase() ?? '';
      final capitalPrice = (stock.capitalPrice as num?)?.toDouble() ?? 0;
      if (stockNumber.isNotEmpty) {
        capitalByStockNumber[stockNumber] = capitalPrice;
      }
      if (itemName.isNotEmpty) {
        capitalByItemName[itemName] = capitalPrice;
      }
    }

    return saleItems
        .where((item) => saleIdsInRange.contains(item.saleId))
        .fold<double>(0, (sum, item) {
      final matchedCapital = capitalByStockNumber[item.itemBarcode] ??
          capitalByItemName[item.itemName.trim().toLowerCase()] ??
          item.retailPrice;
      final lineProfit = (item.quantityBought * item.retailPrice) -
          (item.quantityBought * matchedCapital);
      return sum + lineProfit;
    });
  }

  _DateRange _rangeForPeriod(_PeriodFilter period, DateTime date) {
    final selectedDayStart = DateTime(date.year, date.month, date.day);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    switch (period) {
      case _PeriodFilter.day:
        return _DateRange(start: selectedDayStart, end: end);
      case _PeriodFilter.week:
        final weekStart = DateTime(end.year, end.month, end.day)
            .subtract(Duration(days: end.weekday - 1));
        return _DateRange(
          start: weekStart,
          end: DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + 6,
            23,
            59,
            59,
            999,
          ),
        );
      case _PeriodFilter.month:
        final start = DateTime(end.year, end.month, 1);
        final monthEnd = DateTime(end.year, end.month + 1, 0, 23, 59, 59, 999);
        return _DateRange(start: start, end: monthEnd);
    }
  }

  bool _within(DateTime value, _DateRange range) {
    final local = value.toLocal();
    return !local.isBefore(range.start) && !local.isAfter(range.end);
  }

  List<_BarData> _buildTopExpenseEntities({
    required List<Expense> expenses,
    required _DateRange range,
  }) {
    final grouped = <String, double>{};
    for (final expense in expenses) {
      if (!_within(expense.expenseDate, range)) continue;
      final key = expense.personName.trim().isEmpty
          ? 'Unknown'
          : expense.personName.trim();
      grouped[key] = (grouped[key] ?? 0) + expense.amount;
    }

    final sorted = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(6)
        .map((entry) => _BarData(label: entry.key, value: entry.value))
        .toList();
  }

  Future<void> _pickDate() async {
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

  String _periodLabel(_PeriodFilter period) {
    switch (period) {
      case _PeriodFilter.day:
        return 'Day';
      case _PeriodFilter.week:
        return 'Week';
      case _PeriodFilter.month:
        return 'Month';
    }
  }

  String _rangeLabel(DateTime start, DateTime end) {
    final formatter = DateFormat('MMM d, y');
    return '${formatter.format(start)} - ${formatter.format(end)}';
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
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterCard(summary),
                  const SizedBox(height: 14),
                  _buildQuickStats(summary),
                  const SizedBox(height: 12),
                  _buildEntityBarCard(summary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterCard(_DashboardSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date scope',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _PeriodFilter.values.map((period) {
                final selected = period == _selectedPeriod;
                return ChoiceChip(
                  label: Text(_periodLabel(period)),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.rangeLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: const Text('Pick date'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(_DashboardSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _quickStatCard(
            title: 'Grocery sales (paid only)',
            value: summary.grocerySalesPaid,
            color: const Color(0xFF0F766E),
            icon: Icons.shopping_bag_rounded,
            secondaryLabel: 'Profit',
            secondaryValue: summary.grocerySalesProfit,
          ),
          _quickStatCard(
            title: 'Laundry sales',
            value: summary.laundrySales,
            color: const Color(0xFFEC4899),
            icon: Icons.local_laundry_service_rounded,
          ),
          _quickStatCard(
            title: 'Remittance charge collected',
            value: summary.remittanceChargesCollected,
            color: const Color(0xFFF59E0B),
            icon: Icons.payments_rounded,
          ),
          _quickStatCard(
            title: 'Paid laundry balance',
            value: summary.paidLaundryBalance,
            color: const Color(0xFF7C3AED),
            icon: Icons.payments_outlined,
          ),
          _quickStatCard(
            title: 'Paid grocery balance',
            value: summary.paidGroceryBalance,
            color: const Color(0xFF2563EB),
            icon: Icons.account_balance_wallet_rounded,
          ),
          _quickStatCard(
            title: 'Total unpaid grocery balance',
            value: summary.totalUnpaidGroceryBalance,
            color: const Color(0xFFDC2626),
            icon: Icons.request_quote_rounded,
          ),
          _quickStatCard(
            title: 'Total unpaid laundry balance',
            value: summary.totalUnpaidLaundryBalance,
            color: const Color(0xFFB91C1C),
            icon: Icons.local_laundry_service_outlined,
          ),
        ];

        if (constraints.maxWidth < 780) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              mainAxisSpacing: 8,
              childAspectRatio: 3.9,
            ),
            itemBuilder: (context, index) => cards[index],
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }

  Widget _quickStatCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
    String? secondaryLabel,
    double? secondaryValue,
  }) {
    return Card(
      color: color.withValues(alpha: 0.1),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'P ${value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (secondaryLabel != null && secondaryValue != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$secondaryLabel: P ${secondaryValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntityBarCard(_DashboardSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top expense entities',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Highest total by person',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            if (summary.topExpenseEntities.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('No expense data for this period.')),
              )
            else
              _HorizontalBarWidget(items: summary.topExpenseEntities),
          ],
        ),
      ),
    );
  }
}

class _HorizontalBarWidget extends StatelessWidget {
  const _HorizontalBarWidget({required this.items});

  final List<_BarData> items;

  @override
  Widget build(BuildContext context) {
    final max = items.fold<double>(
      0,
      (highest, item) => item.value > highest ? item.value : highest,
    );
    final safeMax = max <= 0 ? 1.0 : max;

    return Column(
      children: items.map((item) {
        final ratio = (item.value / safeMax).clamp(0, 1).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(
                  'P ${item.value.toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _DashboardSummary {
  const _DashboardSummary({
    required this.periodLabel,
    required this.rangeLabel,
    required this.grocerySalesPaid,
    required this.grocerySalesProfit,
    required this.laundrySales,
    required this.remittanceChargesCollected,
    required this.paidLaundryBalance,
    required this.paidGroceryBalance,
    required this.totalUnpaidGroceryBalance,
    required this.totalUnpaidLaundryBalance,
    required this.topExpenseEntities,
  });

  final String periodLabel;
  final String rangeLabel;
  final double grocerySalesPaid;
  final double grocerySalesProfit;
  final double laundrySales;
  final double remittanceChargesCollected;
  final double paidLaundryBalance;
  final double paidGroceryBalance;
  final double totalUnpaidGroceryBalance;
  final double totalUnpaidLaundryBalance;
  final List<_BarData> topExpenseEntities;
}

class _BarData {
  const _BarData({required this.label, required this.value});

  final String label;
  final double value;
}

class _DateRange {
  const _DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

enum _PeriodFilter { day, week, month }

double calculateCollectedBalancePayments({
  required List<CustomerBalancePayment> payments,
  required DateTime start,
  required DateTime end,
}) {
  return payments.where((payment) {
    final paymentDate = payment.createdAt.toLocal();
    return payment.paymentType == CustomerBalancePaymentType.payment &&
        !paymentDate.isBefore(start) &&
        !paymentDate.isAfter(end);
  }).fold<double>(0, (sum, payment) => sum + payment.amount);
}

double calculateReceivedSalesAmount({required List<Sale> sales}) {
  return sales.fold<double>(0, (sum, sale) {
    final received = sale.amountPaid - sale.changeAmount;
    if (received <= 0) {
      return sum;
    }
    return sum + received;
  });
}

double calculateCustomerOutstandingBalance({
  required List<Sale> sales,
  required List<CustomerBalancePayment> payments,
  required DateTime asOf,
}) {
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
