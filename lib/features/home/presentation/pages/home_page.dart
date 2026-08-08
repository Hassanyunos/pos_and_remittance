import 'package:flutter/material.dart';

import '../../../../core/ui/app_notice.dart';
import '../../../auth/application/auth_service.dart';
import '../../../fund_management/data/repositories/fund_repository.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../user_management/presentation/pages/create_user_page.dart';
import '../../../auth/presentation/pages/change_password_page.dart';
import '../../../customer_management/presentation/pages/customer_management_page.dart';
import '../../../expense_management/presentation/pages/expense_management_page.dart';
import '../../../fund_management/presentation/pages/fund_management_page.dart';
import '../../../grocery_stock_management/presentation/pages/grocery_stock_management_page.dart';
import '../../../laundry_management/presentation/pages/laundry_management_page.dart';
import '../../../laundry_stock_management/presentation/pages/laundry_stock_management_page.dart';
import '../../../remittance_management/presentation/pages/remittance_management_page.dart';
import '../../../sales_management/presentation/pages/sales_management_page.dart';
import '../../../../core/database/app_database.dart';
import 'dashboard_page.dart'
    show
        DashboardPage,
        calculateCollectedBalancePayments,
        calculateReceivedSalesAmount;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    if (user == null) return const LoginPage();

    final ownerModules = <_ModuleCardData>[
      _ModuleCardData(
        title: 'Expenses',
        subtitle: 'Log spending and link it to funds',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ExpenseManagementPage())),
      ),
      _ModuleCardData(
        title: 'Customer',
        subtitle: 'Manage customer profiles and balances',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const CustomerManagementPage())),
      ),
      _ModuleCardData(
        title: 'Remittance',
        subtitle: 'Track cash-in and cash-out records',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const RemittanceManagementPage())),
      ),
      _ModuleCardData(
        title: 'Fund',
        subtitle: 'Review balances and manage zakah',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFEF4444),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const FundManagementPage())),
      ),
      _ModuleCardData(
        title: 'Grocery sales',
        subtitle: 'Process point-of-sale transactions',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF0F766E),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const SalesManagementPage())),
      ),
      _ModuleCardData(
        title: 'Grocery Stock',
        subtitle: 'Monitor inventory, expiry, and alerts',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const GroceryStockManagementPage())),
      ),
      _ModuleCardData(
        title: 'Laundry Sales',
        subtitle: 'Track laundry orders, payments, and statuses',
        icon: Icons.local_laundry_service_rounded,
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const LaundryManagementPage())),
      ),
      _ModuleCardData(
        title: 'Laundry Stock',
        subtitle: 'Manage detergents, supplies, and inventory levels',
        icon: Icons.cleaning_services_rounded,
        color: const Color(0xFF9333EA),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const LaundryStockManagementPage())),
      ),
    ];

    final salespersonModules = <_ModuleCardData>[
      _ModuleCardData(
        title: 'Expenses',
        subtitle: 'Visible to all, owner access only',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFF59E0B),
        enabled: false,
        onTap: () => AppNotice.warning('Only owner can access Expenses.'),
      ),
      _ModuleCardData(
        title: 'Customer',
        subtitle: 'Manage customer profiles and balances',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const CustomerManagementPage())),
      ),
      _ModuleCardData(
        title: 'Remittance',
        subtitle: 'Track cash-in and cash-out records',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF10B981),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const RemittanceManagementPage())),
      ),
      _ModuleCardData(
        title: 'Fund',
        subtitle: 'Visible to all, owner access only',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFEF4444),
        enabled: false,
        onTap: () => AppNotice.warning('Only owner can access Funds.'),
      ),
      _ModuleCardData(
        title: 'Grocery sales',
        subtitle: 'Process point-of-sale transactions',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF0F766E),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const SalesManagementPage())),
      ),
      _ModuleCardData(
        title: 'Grocery Stock',
        subtitle: 'Monitor inventory and alerts',
        icon: Icons.inventory_2_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const GroceryStockManagementPage())),
      ),
      _ModuleCardData(
        title: 'Laundry Sales',
        subtitle: 'Create and update laundry orders',
        icon: Icons.local_laundry_service_rounded,
        color: const Color(0xFFEC4899),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const LaundryManagementPage())),
      ),
      _ModuleCardData(
        title: 'Laundry Stock',
        subtitle: 'Monitor laundry supplies and low stock',
        icon: Icons.cleaning_services_rounded,
        color: const Color(0xFF9333EA),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const LaundryStockManagementPage())),
      ),
    ];

    final modules = user.isOwner ? ownerModules : salespersonModules;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS & Remittance'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Account options',
            onSelected: (value) async {
              switch (value) {
                case 'change_password':
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const ChangePasswordPage()));
                  break;
                case 'create_user':
                  await Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const ManageUserPage()));
                  break;
                case 'logout':
                  await AuthService.instance.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                            builder: (_) => const LoginPage()));
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'change_password',
                  child: ListTile(
                      leading: Icon(Icons.password_rounded),
                      title: Text('Change password'),
                      contentPadding: EdgeInsets.zero)),
              if (user.isOwner)
                const PopupMenuItem(
                    value: 'create_user',
                    child: ListTile(
                        leading: Icon(Icons.person_add_alt_1_rounded),
                        title: Text('Manage users'),
                        contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout_rounded),
                      title: Text('Logout'),
                      contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (user.isOwner) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => const DashboardPage())),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2563EB), Color(0xFF10B981)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.analytics_rounded,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Business Dashboard',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'View sales, remittance, inventory, and expenses',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      _SalespersonMonitoringRow(),
                      const SizedBox(height: 16),
                    ],
                    Text('Operations',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.32,
                      ),
                      itemCount: modules.length,
                      itemBuilder: (context, index) {
                        final module = modules[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: module.enabled ? module.onTap : null,
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: module.color.withValues(
                                        alpha: module.enabled ? 0.16 : 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(module.icon,
                                      color: module.enabled
                                          ? module.color
                                          : Colors.grey,
                                      size: 21),
                                ),
                                const Spacer(),
                                Text(
                                  module.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: module.enabled
                                            ? null
                                            : Colors.grey.shade700,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  module.subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: 11,
                                        color: module.enabled
                                            ? null
                                            : Colors.grey.shade600,
                                      ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModuleCardData {
  const _ModuleCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
}

class _SalespersonMonitoringRow extends StatefulWidget {
  @override
  State<_SalespersonMonitoringRow> createState() =>
      _SalespersonMonitoringRowState();
}

class _SalespersonMonitoringRowState extends State<_SalespersonMonitoringRow> {
  late Future<_SalespersonMonitoringSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _load();
  }

  Future<_SalespersonMonitoringSummary> _load() async {
    await AppDatabase.instance.database;
    final sales = await AppDatabase.instance.saleRepository!.getAll();
    final balancePayments =
        await AppDatabase.instance.customerBalancePaymentRepository!.getAll();
    final funds = await AppDatabase.instance.fundRepository!.getAll();

    final now = DateTime.now().toLocal();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final todaySales = sales.where((sale) {
      final soldAt = sale.soldAt.toLocal();
      return !soldAt.isBefore(start) && !soldAt.isAfter(end);
    }).toList();
    final todayPayments = balancePayments.where((payment) {
      final paymentDate = payment.createdAt.toLocal();
      return !paymentDate.isBefore(start) && !paymentDate.isAfter(end);
    }).toList();

    final receivedSales = calculateReceivedSalesAmount(sales: todaySales);
    final receivedBalances = calculateCollectedBalancePayments(
      payments: todayPayments,
      start: start,
      end: end,
    );
    final grocerySalesToday = receivedSales + receivedBalances;
    final remittanceCash = funds
        .where((fund) => fund.name == FundRepository.remittanceECashName)
        .fold<double>(0, (sum, fund) => sum + fund.currentBalance);

    return _SalespersonMonitoringSummary(
      grocerySalesToday: grocerySalesToday,
      remittanceCash: remittanceCash,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SalespersonMonitoringSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Row(
          children: [
            Expanded(
              child: _monitorCard(
                context,
                title: 'Grocery sales today',
                amount: data?.grocerySalesToday ?? 0,
                color: const Color(0xFF0F766E),
                icon: Icons.point_of_sale_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _monitorCard(
                context,
                title: 'Remittance cash fund',
                amount: data?.remittanceCash ?? 0,
                color: const Color(0xFF0369A1),
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _monitorCard(BuildContext context,
      {required String title,
      required double amount,
      required Color color,
      required IconData icon}) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('₱${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _SalespersonMonitoringSummary {
  const _SalespersonMonitoringSummary(
      {required this.grocerySalesToday, required this.remittanceCash});

  final double grocerySalesToday;
  final double remittanceCash;
}
