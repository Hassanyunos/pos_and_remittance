import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../remittance_management/data/repositories/remittance_repository.dart';
import '../../../sales_management/data/repositories/sale_repository.dart';
import '../../application/customer_balance_service.dart';
import '../../data/models/customer.dart';
import '../../data/models/customer_balance_payment.dart';
import '../../data/repositories/customer_repository.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerHistoryItem {
  const _CustomerHistoryItem({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.createdAt,
    required this.kind,
  });

  final String title;
  final String subtitle;
  final double amount;
  final DateTime createdAt;
  final String kind;
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  CustomerRepository? _repository;
  Future<List<Customer>> _customersFuture = Future.value(const []);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  Customer? _editingCustomer;
  bool _isSaving = false;
  CustomerStatus _selectedCustomerStatus = CustomerStatus.standard;
  File? _selectedImageFile;
  String? _selectedImagePath;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshCustomers();
  }

  Future<void> _refreshCustomers() async {
    final database = await AppDatabase.instance.database;
    _repository = CustomerRepository(database);
    _customersFuture = _repository!.getAll();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveCustomer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final repository = _repository ?? await _ensureRepository();
    final customer = Customer(
      id: _editingCustomer?.id,
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      contactNumber: _contactController.text.trim().isEmpty
          ? null
          : _contactController.text.trim(),
      idPicturePath: _selectedImagePath,
      status: _selectedCustomerStatus,
    );

    if (_editingCustomer == null) {
      await repository.create(customer);
    } else {
      await repository.update(customer.copyWith(id: _editingCustomer!.id));
    }

    if (!mounted) return;
    _resetForm();
    await _refreshCustomers();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_editingCustomer == null
              ? 'Customer created.'
              : 'Customer updated.')),
    );
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _addressController.clear();
    _contactController.clear();
    _selectedImageFile = null;
    _selectedImagePath = null;
    _editingCustomer = null;
    _selectedCustomerStatus = CustomerStatus.standard;
    setState(() {});
  }

  Future<void> _startEditing(Customer customer) async {
    _editingCustomer = customer;
    _nameController.text = customer.name;
    _addressController.text = customer.address ?? '';
    _contactController.text = customer.contactNumber ?? '';
    _selectedImagePath = customer.idPicturePath;
    _selectedCustomerStatus = customer.status;
    final imagePath = customer.idPicturePath;
    _selectedImageFile = imagePath == null ? null : File(imagePath);
    setState(() {});
  }

  Future<CustomerRepository> _ensureRepository() async {
    if (_repository != null) return _repository!;
    final database = await AppDatabase.instance.database;
    _repository = CustomerRepository(database);
    return _repository!;
  }

  Future<void> _deleteCustomer(Customer customer) async {
    if (customer.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete customer'),
        content: Text('Delete ${customer.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    final repository = _repository ?? await _ensureRepository();
    await repository.delete(customer.id!);
    await _refreshCustomers();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Customer deleted.')));
    }
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final pickedFile =
        await _picker.pickImage(source: source, imageQuality: 90);
    if (pickedFile == null) return;
    setState(() {
      _selectedImageFile = File(pickedFile.path);
      _selectedImagePath = pickedFile.path;
    });
  }

  Future<void> _showCustomerDialog({Customer? customer}) async {
    if (customer != null) {
      await _startEditing(customer);
    } else {
      _resetForm();
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(customer == null ? 'Add customer' : 'Edit customer'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(labelText: 'Customer name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a customer name.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactController,
                      decoration:
                          const InputDecoration(labelText: 'Contact number'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CustomerStatus>(
                      initialValue: _selectedCustomerStatus,
                      decoration:
                          const InputDecoration(labelText: 'Credit status'),
                      items: const [
                        DropdownMenuItem(
                            value: CustomerStatus.standard,
                            child: Text('Standard')),
                        DropdownMenuItem(
                            value: CustomerStatus.allowedToBorrow,
                            child: Text('Allowed to borrow')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedCustomerStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(fromCamera: true),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take photo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(fromCamera: false),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Choose photo'),
                          ),
                        ),
                      ],
                    ),
                    if (_selectedImageFile != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_selectedImageFile!,
                            height: 160, fit: BoxFit.cover),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveCustomerFromDialog(dialogContext),
              icon: const Icon(Icons.save),
              label: Text(
                  customer == null ? 'Create customer' : 'Update customer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveCustomerFromDialog(BuildContext dialogContext) async {
    await _saveCustomer();
    if (!mounted || !dialogContext.mounted) return;
    Navigator.pop(dialogContext);
  }

  Future<void> _showBalanceDialog(Customer customer) async {
    final balanceAmount = customer.currentBalance.toStringAsFixed(2);
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController(text: balanceAmount);
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Manage balance • ${customer.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Current balance: ₱${customer.currentBalance.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Payment amount'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a payment amount.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final amount = double.tryParse(amountController.text);
              if (amount == null) return;
              try {
                await CustomerBalanceService.instance.recordBalancePayment(
                    customerId: customer.id!,
                    amount: amount,
                    note: noteController.text);
                if (!mounted) return;
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              } catch (error) {
                if (!mounted) return;
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.toString())));
              }
            },
            child: const Text('Record payment'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _refreshCustomers();
    }
  }

  Future<void> _showBalanceHistory(Customer customer) async {
    final payments = await CustomerBalanceService.instance
        .getPaymentsForCustomer(customer.id!);
    final sales =
        await SaleRepository(await AppDatabase.instance.database).getAll();
    final remittances =
        await RemittanceRepository(await AppDatabase.instance.database)
            .getAll();
    if (!mounted) return;

    final history = <_CustomerHistoryItem>[
      ...payments.map((payment) => _CustomerHistoryItem(
            title: payment.paymentType == CustomerBalancePaymentType.payment
                ? 'Balance payment'
                : 'Balance carried',
            subtitle: payment.note ?? 'No note',
            amount: payment.amount,
            createdAt: payment.createdAt,
            kind: 'balance',
          )),
      ...sales
          .where((sale) => sale.customerId == customer.id)
          .map((sale) => _CustomerHistoryItem(
                title: 'Purchase',
                subtitle: sale.receiptNumber,
                amount: sale.amountPayable,
                createdAt: sale.soldAt,
                kind: 'sale',
              )),
      ...remittances
          .where((remittance) => remittance.customerId == customer.id)
          .map((remittance) => _CustomerHistoryItem(
                title: 'Remittance',
                subtitle: remittance.referenceNumber,
                amount: remittance.amount,
                createdAt: remittance.processedAt ?? DateTime.now(),
                kind: 'remittance',
              )),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('History • ${customer.name}'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('No transaction history yet.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return ListTile(
                      title: Text(
                          '${item.title} • ₱${item.amount.toStringAsFixed(2)}'),
                      trailing: Text(
                          item.createdAt.toLocal().toString().substring(0, 16)),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showCustomerDetails(Customer customer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (sheetContext, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(customer.name,
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            if (customer.idPicturePath != null &&
                customer.idPicturePath!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(customer.idPicturePath!),
                    fit: BoxFit.cover),
              )
            else
              const Text('No image attached.'),
            const SizedBox(height: 16),
            if (customer.address != null && customer.address!.isNotEmpty) ...[
              Text('Address', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(customer.address!),
              const SizedBox(height: 12),
            ],
            if (customer.contactNumber != null &&
                customer.contactNumber!.isNotEmpty) ...[
              Text('Contact number',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(customer.contactNumber!),
              const SizedBox(height: 12),
            ],
            Text('Credit status',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(customer.status == CustomerStatus.allowedToBorrow
                ? 'Allowed to borrow'
                : 'Standard'),
            const SizedBox(height: 4),
            Text(
                'Current balance: ₱${customer.currentBalance.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showCustomerDialog(customer: customer);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _deleteCustomer(customer);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add customer'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Customer>>(
          future: _customersFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final customers = snapshot.data!;
            final filteredCustomers = customers.where((customer) {
              final query = _searchQuery.trim().toLowerCase();
              if (query.isEmpty) return true;
              final searchableText = [
                customer.name,
                customer.address ?? '',
                customer.contactNumber ?? ''
              ].join(' ').toLowerCase();
              return searchableText.contains(query);
            }).toList();
            if (filteredCustomers.isEmpty) {
              return const Center(
                  child: Text('No customers match the current search.'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name, address, or contact',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) => setState(
                          () => _searchQuery = value.trim().toLowerCase()),
                    ),
                  ),
                ),
                ...filteredCustomers.map((customer) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(customer.name.isNotEmpty
                                ? customer.name[0].toUpperCase()
                                : 'C')),
                        title: Text(customer.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [customer.address, customer.contactNumber]
                                  .where((value) =>
                                      value != null && value.isNotEmpty)
                                  .cast<String>()
                                  .join(' • '),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              customer.status == CustomerStatus.allowedToBorrow
                                  ? 'Allowed to borrow • Balance ₱${customer.currentBalance.toStringAsFixed(2)}'
                                  : 'Standard • Balance ₱${customer.currentBalance.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.account_balance_wallet),
                                onPressed: () => _showBalanceDialog(customer)),
                            IconButton(
                                icon: const Icon(Icons.history),
                                onPressed: () => _showBalanceHistory(customer)),
                            IconButton(
                                icon: const Icon(Icons.visibility),
                                onPressed: () =>
                                    _showCustomerDetails(customer)),
                            IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteCustomer(customer)),
                          ],
                        ),
                      ),
                    )),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
