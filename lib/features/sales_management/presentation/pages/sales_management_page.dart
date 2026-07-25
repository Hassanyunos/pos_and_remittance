import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../customer_management/data/models/customer.dart';
import '../../../grocery_stock_management/data/models/grocery_stock_item.dart';
import '../../application/sales_service.dart';
import '../../data/models/sale.dart';

class SalesManagementPage extends StatefulWidget {
  const SalesManagementPage({super.key});

  @override
  State<SalesManagementPage> createState() => _SalesManagementPageState();
}

class _SaleCompletionDetails {
  const _SaleCompletionDetails({required this.customer, required this.amountPaid});

  final Customer? customer;
  final double amountPaid;
}

class _SalesManagementPageState extends State<SalesManagementPage> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final List<SalesCartItem> _cart = [];
  List<GroceryStockItem> _stockItems = const [];
  List<Customer> _customers = const [];
  Customer? _selectedCustomer;
  bool _isLoading = true;
  String _searchQuery = '';
  double _lastChangeAmount = 0;
  String _historySearchQuery = '';
  DateTime? _historyFilterDate;
  static const _draftKey = 'sales_management_draft';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      unawaited(_saveDraft());
    }
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'selectedCustomerId': _selectedCustomer?.id,
      'cart': _cart.map((item) => {
        'stockItemId': item.stockItemId,
        'itemName': item.itemName,
        'itemBarcode': item.itemBarcode,
        'quantity': item.quantity,
        'retailPrice': item.retailPrice,
      }).toList(),
      'searchQuery': _searchQuery,
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final customerId = decoded['selectedCustomerId'] as int?;
      final selectedCustomer = _customers.where((customer) => customer.id == customerId).firstOrNull;
      final cartItems = (decoded['cart'] as List<dynamic>? ?? []).map((entry) {
        final item = entry as Map<String, dynamic>;
        return SalesCartItem(
          stockItemId: item['stockItemId'] as int,
          itemName: item['itemName'] as String,
          itemBarcode: item['itemBarcode'] as String,
          quantity: item['quantity'] as int,
          retailPrice: (item['retailPrice'] as num).toDouble(),
        );
      }).toList();
      final searchQuery = decoded['searchQuery'] as String? ?? '';
      if (!mounted) return;
      setState(() {
        _selectedCustomer = selectedCustomer;
        _cart.clear();
        _cart.addAll(cartItems);
        _searchQuery = searchQuery;
        _searchController.text = searchQuery;
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    try {
      await AppDatabase.instance.database;
      final stockItems = await AppDatabase.instance.groceryStockRepository!.getAll();
      final customers = await AppDatabase.instance.customerRepository!.getAll();
      if (!mounted) return;
      setState(() {
        _stockItems = stockItems;
        _customers = customers;
        _isLoading = false;
      });
      await _restoreDraft();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _addToCart(GroceryStockItem item) {
    final availableStock = item.quantityInStock;
    if (availableStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This item is out of stock.')));
      return;
    }

    final existing = _cart.where((entry) => entry.stockItemId == item.id).firstOrNull;
    final nextQuantity = (existing?.quantity ?? 0) + 1;
    if (nextQuantity > availableStock) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough stock for this quantity.')));
      return;
    }

    setState(() {
      if (existing != null) {
        _cart.remove(existing);
      }
      _cart.add(SalesCartItem(
        stockItemId: item.id!,
        itemName: item.itemName,
        itemBarcode: item.stockNumber,
        quantity: nextQuantity,
        retailPrice: item.retailPrice,
      ));
    });
    unawaited(_saveDraft());
  }

  void _removeFromCart(SalesCartItem item) {
    setState(() => _cart.remove(item));
    unawaited(_saveDraft());
  }

  Future<void> _completeSale() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add items to the cart first.')));
      return;
    }

    final payableAmount = _cart.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final completion = await _showPaymentDialog(payableAmount);
    if (completion == null) {
      return;
    }

    try {
      final receiptNumber = SalesService.instance.generateReceiptNumber();
      await SalesService.instance.createSale(
        receiptNumber: receiptNumber,
        customerId: completion.customer?.id,
        customerName: completion.customer?.name,
        cartItems: _cart,
        amountPaid: completion.amountPaid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sale completed successfully.')));
      setState(() {
        _cart.clear();
        _selectedCustomer = completion.customer;
        _lastChangeAmount = completion.amountPaid - payableAmount;
      });
      await _saveDraft();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<_SaleCompletionDetails?> _showPaymentDialog(double payableAmount) async {
    final amountController = TextEditingController(text: payableAmount.toStringAsFixed(2));
    Customer? selectedCustomer = _selectedCustomer;
    return showDialog<_SaleCompletionDetails>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Complete sale'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subtotal: ₱${payableAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Text('Amount due: ₱${payableAmount.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Customer?>(
                    initialValue: selectedCustomer,
                    decoration: const InputDecoration(labelText: 'Customer (optional)'),
                    items: [
                      const DropdownMenuItem<Customer?>(value: null, child: Text('Walk-in customer')),
                      ..._customers.map((customer) => DropdownMenuItem<Customer?>(value: customer, child: Text(customer.name))),
                    ],
                    onChanged: (value) => setState(() => selectedCustomer = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Cash received'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () {
                    final amountPaid = double.tryParse(amountController.text);
                    if (amountPaid == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
                      return;
                    }
                    if (amountPaid < payableAmount) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Amount paid cannot be less than the amount due.')));
                      return;
                    }
                    Navigator.of(dialogContext).pop(_SaleCompletionDetails(customer: selectedCustomer, amountPaid: amountPaid));
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = _cart.fold<double>(0, (sum, item) => sum + item.lineTotal);
    final amountPayable = totalPrice;
    final changeAmount = _lastChangeAmount;

    final filteredStock = _stockItems.where((item) {
      final query = _searchQuery.trim().toLowerCase();
      if (query.isEmpty) return true;
      return item.itemName.toLowerCase().contains(query) ||
          item.stockNumber.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Sales management')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: constraints.maxHeight * 0.38,
                          child: _buildCartSummary(totalPrice, amountPayable, changeAmount),
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildStockSelector(filteredStock)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildHeader() => Row(
        children: [
          Expanded(child: _buildDailySalesSummary()),
          const SizedBox(width: 12),
          FilledButton.tonalIcon(
            onPressed: _showSalesHistory,
            icon: const Icon(Icons.history_rounded),
            label: const Text('History'),
          ),
        ],
      );

  Widget _buildDailySalesSummary() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.today_rounded, color: Colors.teal),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Today sales', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    FutureBuilder<double>(
                      future: _getTodaySalesTotal(),
                      builder: (context, snapshot) {
                        final value = snapshot.data ?? 0;
                        return Text('₱${value.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Future<double> _getTodaySalesTotal() async {
    final sales = await SalesService.instance.getSales();
    return SalesService.instance.calculateDailySalesTotal(sales: sales);
  }

  Widget _buildCartSummary(double totalPrice, double amountPayable, double changeAmount) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Current cart', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    _cart.isEmpty
                        ? 'No selected items'
                        : '${_cart.length} selected item${_cart.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_cart.isEmpty)
                const Text('No items selected yet.')
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${item.quantity} × ₱${item.retailPrice.toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 96,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '₱${item.lineTotal.toStringAsFixed(2)}',
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _removeFromCart(item),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const Divider(),
              _buildAmountRow('Subtotal', totalPrice),
              _buildAmountRow('Amount due', amountPayable),
              _buildAmountRow('Change', changeAmount),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _completeSale,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Complete sale'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildAmountRow(String label, double value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value.toStringAsFixed(2)),
        ],
      );

  Future<void> _showSalesHistory() async {
    final sales = await SalesService.instance.getSales();
    if (!mounted) return;
    final filteredSales = List<Sale>.from(sales);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final visibleSales = filteredSales.where((sale) {
              final matchesText = _historySearchQuery.isEmpty ||
                  sale.receiptNumber.toLowerCase().contains(_historySearchQuery.toLowerCase()) ||
                  (sale.customerName?.toLowerCase().contains(_historySearchQuery.toLowerCase()) ?? false) ||
                  sale.amountPaid.toStringAsFixed(2).contains(_historySearchQuery);
              final saleDate = sale.soldAt.toLocal();
              final matchesDate = _historyFilterDate == null ||
                  (saleDate.year == _historyFilterDate!.year && saleDate.month == _historyFilterDate!.month && saleDate.day == _historyFilterDate!.day);
              return matchesText && matchesDate;
            }).toList();

            return AlertDialog(
              title: const Text('Sales history'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Search receipt, customer, or amount', prefixIcon: Icon(Icons.search)),
                      onChanged: (value) => setState(() => _historySearchQuery = value.trim()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _historyFilterDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setState(() => _historyFilterDate = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_rounded),
                            label: Text(_historyFilterDate == null ? 'Filter by date' : '${_historyFilterDate!.day}/${_historyFilterDate!.month}/${_historyFilterDate!.year}'),
                          ),
                        ),
                        if (_historyFilterDate != null)
                          TextButton(
                            onPressed: () => setState(() => _historyFilterDate = null),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: visibleSales.length,
                        itemBuilder: (context, index) {
                          final sale = visibleSales[index];
                          return ListTile(
                            title: Text(
                              '₱${sale.amountPaid.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text('${sale.customerName ?? 'Walk-in'} • ${sale.receiptNumber} • ${sale.soldAt.toLocal().toString().substring(0, 16)}'),
                            trailing: TextButton(
                              onPressed: () => _showReceiptPreview(sale),
                              child: const Text('View receipt'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showReceiptPreview(Sale sale) async {
    final items = await AppDatabase.instance.saleItemRepository!.getBySaleId(sale.id!);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Receipt ${sale.receiptNumber}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer: ${sale.customerName ?? 'Walk-in'}'),
              const SizedBox(height: 8),
              Text('Date: ${sale.soldAt.toLocal().toString().substring(0, 16)}'),
              const SizedBox(height: 8),
              Text('Receipt number: ${sale.receiptNumber}'),
              const SizedBox(height: 8),
              Text('Amount due: ₱${sale.amountPayable.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Cash received: ₱${sale.amountPaid.toStringAsFixed(2)}'),
              const SizedBox(height: 8),
              Text('Change: ₱${sale.changeAmount.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              const Text('Items bought', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${item.itemName} x${item.quantityBought}')),
                        Text('₱${item.retailPrice.toStringAsFixed(2)}'),
                      ],
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Print')),
        ],
      ),
    );
  }

  Widget _buildStockSelector(List<GroceryStockItem> filteredStock) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(labelText: 'Search stock', prefixIcon: Icon(Icons.search)),
                onChanged: (value) async {
                  setState(() => _searchQuery = value.trim().toLowerCase());
                  await _saveDraft();
                },
              ),
              const SizedBox(height: 12),
              if (filteredStock.isEmpty)
                const Text('No stock items match the current search.')
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: filteredStock.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = filteredStock[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.itemName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.stockNumber} • stock ${item.quantityInStock} • ₱${item.retailPrice.toStringAsFixed(2)}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: item.quantityInStock > 0 ? () => _addToCart(item) : null,
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveDraft());
    _searchController.dispose();
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
