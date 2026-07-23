import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';

class CustomerManagementPage extends StatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  State<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends State<CustomerManagementPage> {
  CustomerRepository? _repository;
  Future<List<Customer>> _customersFuture = Future.value(const []);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _picker = ImagePicker();
  Customer? _editingCustomer;
  bool _isSaving = false;
  File? _selectedImageFile;
  String? _selectedImagePath;

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

  Future<void> _saveCustomer({BuildContext? dialogContext}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = dialogContext == null ? null : Navigator.of(dialogContext);
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
    );

    if (_editingCustomer == null) {
      await repository.create(customer);
    } else {
      await repository.update(customer.copyWith(id: _editingCustomer!.id));
    }

    if (!mounted) return;
    _resetForm();
    await _refreshCustomers();
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
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
    setState(() {});
  }

  Future<void> _startEditing(Customer customer) async {
    _editingCustomer = customer;
    _nameController.text = customer.name;
    _addressController.text = customer.address ?? '';
    _contactController.text = customer.contactNumber ?? '';
    _selectedImagePath = customer.idPicturePath;
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
    if (customer == null) {
      _resetForm();
    } else {
      await _startEditing(customer);
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(customer == null ? 'Create customer' : 'Edit customer'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        customer == null
                            ? 'Add a new customer'
                            : 'Update the customer details',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
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
              onPressed: () {
                Navigator.pop(dialogContext);
                _resetForm();
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _saveCustomer(dialogContext: dialogContext),
              icon: const Icon(Icons.save),
              label: Text(
                  customer == null ? 'Create customer' : 'Update customer'),
            ),
          ],
        );
      },
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await _showCustomerDialog(customer: customer);
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
      appBar: AppBar(
        title: const Text('Customer management'),
        actions: [
          IconButton(
            tooltip: 'Create customer',
            onPressed: () => _showCustomerDialog(),
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Customer>>(
          future: _customersFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final customers = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text('Customers',
                            style: Theme.of(context).textTheme.titleLarge)),
                  ],
                ),
                const SizedBox(height: 12),
                if (customers.isEmpty)
                  const Text(
                      'No customers yet. Create one from the button above.')
                else
                  ...customers.map(
                    (customer) => Card(
                      child: ListTile(
                        title: Text(customer.name),
                        subtitle: Text(
                          [customer.address, customer.contactNumber]
                              .where(
                                  (value) => value != null && value.isNotEmpty)
                              .cast<String>()
                              .join(' • '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => _showCustomerDetails(customer),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteCustomer(customer),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
    super.dispose();
  }
}
