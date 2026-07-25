import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/database/app_database.dart';
import '../../../customer_management/application/customer_service.dart';
import '../../../customer_management/data/models/customer.dart';
import '../../../fund_management/data/models/fund.dart';
import '../../application/remittance_service.dart';
import '../../data/models/remittance.dart';

class RemittanceManagementPage extends StatefulWidget {
  const RemittanceManagementPage({super.key});

  @override
  State<RemittanceManagementPage> createState() => _RemittanceManagementPageState();
}

class _RemittanceManagementPageState extends State<RemittanceManagementPage> {
  Future<List<Remittance>> _remittancesFuture = Future.value(const []);
  Future<List<Customer>> _customersFuture = Future.value(const []);
  Future<List<Fund>> _fundsFuture = Future.value(const []);

  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _amountController = TextEditingController();
  final _chargeController = TextEditingController();
  final _notesController = TextEditingController();
  final _editReferenceController = TextEditingController();
  final _editAmountController = TextEditingController();
  final _editChargeController = TextEditingController();
  final _editNotesController = TextEditingController();
  final _picker = ImagePicker();

  int? _selectedFundId;
  RemittanceType _selectedType = RemittanceType.cashIn;
  RemittanceStatus _selectedStatus = RemittanceStatus.receivedByCustomer;
  RemittanceType _editSelectedType = RemittanceType.cashIn;
  RemittanceStatus _editSelectedStatus = RemittanceStatus.receivedByCustomer;
  int? _editSelectedCustomerId;
  String? _editSelectedImagePath;
  File? _editSelectedImageFile;
  bool _isEditing = false;
  int? _selectedCustomerId;
  String? _selectedImagePath;
  File? _selectedImageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _remittancesFuture = RemittanceService.instance.getRemittances();
    _customersFuture = CustomerService.instance.getCustomers();
    _fundsFuture = AppDatabase.instance.fundRepository!.getAll();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showAddDialog({required List<Customer> customers, required List<Fund> funds}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add remittance record'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _selectedFundId,
                          decoration: const InputDecoration(labelText: 'eCash fund'),
                          items: funds
                              .map((fund) => DropdownMenuItem<int>(
                                    value: fund.id,
                                    child: Text('${fund.name} (${fund.currentBalance.toStringAsFixed(2)})'),
                                  ))
                              .toList(),
                          onChanged: (value) => setDialogState(() => _selectedFundId = value),
                          validator: (value) => value == null ? 'Select an eCash fund.' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RemittanceType>(
                          initialValue: _selectedType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: RemittanceType.cashIn, child: Text('Cash In')),
                            DropdownMenuItem(value: RemittanceType.cashOut, child: Text('Cash Out')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              _selectedType = value ?? RemittanceType.cashIn;
                              _selectedStatus = RemittanceService.instance.getInitialStatusForType(_selectedType);
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RemittanceStatus>(
                          initialValue: _selectedStatus,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: _selectedType == RemittanceType.cashIn
                              ? const [
                                  DropdownMenuItem(value: RemittanceStatus.receivedByCustomer, child: Text('Received by customer')),
                                ]
                              : const [
                                  DropdownMenuItem(value: RemittanceStatus.pending, child: Text('Not received')),
                                  DropdownMenuItem(value: RemittanceStatus.receivedByCustomer, child: Text('Received by customer')),
                                ],
                          onChanged: (value) => setDialogState(() => _selectedStatus = value ?? RemittanceStatus.pending),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _referenceController,
                          decoration: const InputDecoration(labelText: 'Reference number'),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter a reference number.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Amount'),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter amount.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _chargeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Charge'),
                          validator: (value) => value == null || value.trim().isEmpty ? 'Enter charge.' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedCustomerId,
                          decoration: const InputDecoration(labelText: 'Existing customer (optional)'),
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('None')),
                            ...customers.map((customer) => DropdownMenuItem<int>(
                                  value: customer.id,
                                  child: Text(customer.name),
                                )),
                          ],
                          onChanged: (value) => setDialogState(() => _selectedCustomerId = value),
                        ),
                        const SizedBox(height: 12),
                        const Text('Picture ID (optional)'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Notes'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(fromCamera: true, setDialogState: setDialogState),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Take photo'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(fromCamera: false, setDialogState: setDialogState),
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
                            child: Image.file(_selectedImageFile!, height: 160, fit: BoxFit.cover),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _saveRemittance(dialogContext: dialogContext),
                  icon: const Icon(Icons.save),
                  label: const Text('Record remittance'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveRemittance({required BuildContext dialogContext}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    final messenger = ScaffoldMessenger.maybeOf(dialogContext);
    final navigator = Navigator.of(dialogContext);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final charge = double.tryParse(_chargeController.text.trim()) ?? 0;

    try {
      await RemittanceService.instance.addRemittance(
        fundId: _selectedFundId!,
        remittanceType: _selectedType,
        referenceNumber: _referenceController.text.trim(),
        amount: amount,
        charge: charge,
        customerId: _selectedCustomerId,
        newCustomerName: null,
        newCustomerAddress: null,
        newCustomerContact: null,
        customerIdPicturePath: _selectedImagePath,
        remittanceStatus: _selectedStatus,
        notes: _notesController.text.trim(),
      );
      await _loadData();
      if (!mounted) return;
      navigator.pop();
      _resetForm();
      messenger?.showSnackBar(const SnackBar(content: Text('Remittance recorded.')));
    } catch (error) {
      if (mounted) {
        messenger?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _resetForm() {
    _referenceController.clear();
    _amountController.clear();
    _chargeController.clear();
    _notesController.clear();
    _selectedFundId = null;
    _selectedType = RemittanceType.cashIn;
    _selectedStatus = RemittanceService.instance.getInitialStatusForType(_selectedType);
    _selectedCustomerId = null;
    _selectedImagePath = null;
    _selectedImageFile = null;
    setState(() {});
  }

  Future<void> _pickImage({required bool fromCamera, void Function(void Function())? setDialogState}) async {
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 90);
    if (pickedFile == null) return;
    if (setDialogState != null) {
      setDialogState(() {
        _selectedImageFile = File(pickedFile.path);
        _selectedImagePath = pickedFile.path;
      });
    } else {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
        _selectedImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _pickEditImage({required bool fromCamera, void Function(void Function())? setDialogState}) async {
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 90);
    if (pickedFile == null) return;
    if (setDialogState != null) {
      setDialogState(() {
        _editSelectedImageFile = File(pickedFile.path);
        _editSelectedImagePath = pickedFile.path;
      });
    } else {
      setState(() {
        _editSelectedImageFile = File(pickedFile.path);
        _editSelectedImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _showRemittanceDetailsDialog({required Remittance remittance, required Fund? fund, required Customer? customer}) async {
    if (!mounted) return;
    _editReferenceController.text = remittance.referenceNumber;
    _editAmountController.text = remittance.amount.toString();
    _editChargeController.text = remittance.charge.toString();
    _editNotesController.text = remittance.notes ?? '';
    _editSelectedType = remittance.remittanceType;
    _editSelectedStatus = remittance.remittanceStatus;
    _editSelectedCustomerId = remittance.customerId;
    _editSelectedImagePath = remittance.customerIdPicturePath;
    _editSelectedImageFile = remittance.customerIdPicturePath != null && remittance.customerIdPicturePath!.isNotEmpty
        ? File(remittance.customerIdPicturePath!)
        : null;
    _isEditing = false;
    setState(() {});

    final dialogContextReference = context;
    final customers = await CustomerService.instance.getCustomers();
    if (!mounted || !dialogContextReference.mounted) return;

    await showDialog<void>(
      context: dialogContextReference,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(remittance.referenceNumber),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isEditing) ...[

                        const Text('Edit details', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RemittanceType>(
                          initialValue: _editSelectedType,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: const [
                            DropdownMenuItem(value: RemittanceType.cashIn, child: Text('Cash In')),
                            DropdownMenuItem(value: RemittanceType.cashOut, child: Text('Cash Out')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              _editSelectedType = value ?? RemittanceType.cashIn;
                              _editSelectedStatus = RemittanceService.instance.getInitialStatusForType(_editSelectedType);
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<RemittanceStatus>(
                          initialValue: _editSelectedStatus,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: _editSelectedType == RemittanceType.cashIn
                              ? const [
                                  DropdownMenuItem(value: RemittanceStatus.receivedByCustomer, child: Text('Received by customer')),
                                ]
                              : const [
                                  DropdownMenuItem(value: RemittanceStatus.pending, child: Text('Not received')),
                                  DropdownMenuItem(value: RemittanceStatus.receivedByCustomer, child: Text('Received by customer')),
                                ],
                          onChanged: (value) => setDialogState(() => _editSelectedStatus = value ?? RemittanceStatus.pending),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: _editReferenceController, decoration: const InputDecoration(labelText: 'Reference number')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _editAmountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
                        const SizedBox(height: 12),
                        TextFormField(controller: _editChargeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Charge')),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: _editSelectedCustomerId,
                          decoration: const InputDecoration(labelText: 'Customer (optional)'),
                          items: [
                            const DropdownMenuItem<int>(value: null, child: Text('None')),
                            ...customers.map((customer) => DropdownMenuItem<int>(
                                  value: customer.id,
                                  child: Text(customer.name),
                                )),
                          ],
                          onChanged: (value) => setDialogState(() => _editSelectedCustomerId = value),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(controller: _editNotesController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickEditImage(fromCamera: true, setDialogState: setDialogState),
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Take photo'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickEditImage(fromCamera: false, setDialogState: setDialogState),
                                icon: const Icon(Icons.photo_library),
                                label: const Text('Choose photo'),
                              ),
                            ),
                          ],
                        ),
                        if (_editSelectedImageFile != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_editSelectedImageFile!, height: 160, fit: BoxFit.cover),
                          ),
                        ],
                      ] else ...[
                        _detailRow('Type', remittance.remittanceType.name == 'cashIn' ? 'Cash In' : 'Cash Out'),
                        _detailRow('Amount', remittance.amount.toStringAsFixed(2)),
                        _detailRow('Charge', remittance.charge.toStringAsFixed(2)),
                        _detailRow('Status', RemittanceService.instance.getStatusLabel(remittance.remittanceStatus, remittanceType: remittance.remittanceType)),
                        _detailRow('Fund', fund?.name ?? 'Unknown'),
                        _detailRow('Customer', customer?.name ?? 'None'),
                        _detailRow('Reference', remittance.referenceNumber),
                        if (remittance.notes != null && remittance.notes!.isNotEmpty) _detailRow('Notes', remittance.notes!),
                        if (remittance.processedAt != null) _detailRow('Processed at', remittance.processedAt!.toString()),
                        if (remittance.customerIdPicturePath != null && remittance.customerIdPicturePath!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text('Picture ID'),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(remittance.customerIdPicturePath!), fit: BoxFit.cover),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')),
                if (!_isEditing)
                  TextButton(onPressed: () => setDialogState(() => _isEditing = true), child: const Text('Edit')),
                if (_isEditing)
                  FilledButton.icon(
                    onPressed: () => _saveEditedRemittance(dialogContext: dialogContext, remittance: remittance),
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveEditedRemittance({required BuildContext dialogContext, required Remittance remittance}) async {
    final messenger = ScaffoldMessenger.maybeOf(dialogContext);
    final navigator = Navigator.of(dialogContext);
    final amount = double.tryParse(_editAmountController.text.trim()) ?? 0;
    final charge = double.tryParse(_editChargeController.text.trim()) ?? 0;

    try {
      await RemittanceService.instance.updateRemittance(
        existingRemittance: remittance,
        remittanceType: _editSelectedType,
        referenceNumber: _editReferenceController.text,
        amount: amount,
        charge: charge,
        customerId: _editSelectedCustomerId,
        customerIdPicturePath: _editSelectedImagePath,
        remittanceStatus: _editSelectedStatus,
        notes: _editNotesController.text,
      );
      await _loadData();
      if (!mounted) return;
      navigator.pop();
      messenger?.showSnackBar(const SnackBar(content: Text('Remittance updated.')));
    } catch (error) {
      if (mounted) {
        messenger?.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(value)),
          ],
        ),
      );

  Future<void> _deleteRemittance(Remittance remittance) async {
    if (!mounted) return;
    final dialogContext = context;
    final messenger = ScaffoldMessenger.of(dialogContext);
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Delete remittance'),
        content: Text('Delete reference ${remittance.referenceNumber}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await RemittanceService.instance.deleteRemittance(remittance.id!);
      await _loadData();
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Remittance deleted.')));
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remittance management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final snapshot = await Future.wait([_remittancesFuture, _customersFuture, _fundsFuture]);
          if (!mounted) return;
          final customers = snapshot[1] as List<Customer>;
          final funds = snapshot[2] as List<Fund>;
          final eCashFunds = funds.where((fund) => fund.fundType == FundType.eCash).toList();
          await _showAddDialog(customers: customers, funds: eCashFunds);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add remittance'),
      ),
      body: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([_remittancesFuture, _customersFuture, _fundsFuture]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final remittances = snapshot.data![0] as List<Remittance>;
            if (remittances.isEmpty) {
              return const Center(child: Text('No remittances yet.'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: Colors.green),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Remittance overview', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Keep financial movement clear and easy to review.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...remittances.map((remittance) {
                  final funds = snapshot.data![2] as List<Fund>;
                  final customers = snapshot.data![1] as List<Customer>;
                  final fund = funds.where((item) => item.id == remittance.fundId).isEmpty
                      ? null
                      : funds.firstWhere((item) => item.id == remittance.fundId);
                  final customer = customers.where((item) => item.id == remittance.customerId).isEmpty
                      ? null
                      : customers.firstWhere((item) => item.id == remittance.customerId);
                  return Card(
                    child: ListTile(
                      title: Text(remittance.referenceNumber),
                      subtitle: Text('${remittance.remittanceType.name == 'cashIn' ? 'Cash In' : 'Cash Out'} • ${remittance.amount.toStringAsFixed(2)} • ${remittance.charge.toStringAsFixed(2)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () => _showRemittanceDetailsDialog(remittance: remittance, fund: fund, customer: customer),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteRemittance(remittance),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _amountController.dispose();
    _chargeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
