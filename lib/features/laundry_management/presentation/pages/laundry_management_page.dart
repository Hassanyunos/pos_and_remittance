import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_notice.dart';
import '../../../customer_management/application/customer_service.dart';
import '../../../customer_management/data/models/customer.dart';
import '../../../laundry_stock_management/application/laundry_service_item_service.dart';
import '../../../laundry_stock_management/application/laundry_stock_service.dart';
import '../../../laundry_stock_management/data/models/laundry_service_item.dart';
import '../../../laundry_stock_management/data/models/laundry_stock_item.dart';
import '../../application/laundry_service.dart';
import '../../data/models/laundry_order.dart';

class LaundryManagementPage extends StatefulWidget {
  const LaundryManagementPage({super.key});

  @override
  State<LaundryManagementPage> createState() => _LaundryManagementPageState();
}

enum _LaundryBalanceFilter { all, withBalance, fullyPaid }

class _LaundryManagementPageState extends State<LaundryManagementPage> {
  late Future<List<LaundryOrder>> _ordersFuture;

  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();

  final _customerLookupController = TextEditingController();
  final _paidAddOnLookupController = TextEditingController();
  final _walkInNameController = TextEditingController();
  final _customerContactController = TextEditingController();
  final _weightController = TextEditingController(text: '0');
  final _clothesCountController = TextEditingController(text: '0');
  final _laundryAmountController = TextEditingController(text: '0');
  final _totalAmountDueController = TextEditingController(text: '0');
  final _amountPaidController = TextEditingController(text: '0');
  final _balanceDueController = TextEditingController(text: '0');
  final _changeController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  List<Customer> _customers = const [];
  List<LaundryStockItem> _availableAddOns = const [];
  List<LaundryServiceItem> _availableServices = const [];
  Future<void>? _lookupLoadTask;

  String _searchQuery = '';
  LaundryOrderStatus? _statusFilter;
  _LaundryBalanceFilter _balanceFilter = _LaundryBalanceFilter.all;
  DateTime? _dateFilter;

  String _customerLookupQuery = '';
  String _paidAddOnLookupQuery = '';

  int? _selectedCustomerId;
  int? _selectedServiceId;
  String? _selectedServiceName;
  LaundryOrderStatus _selectedStatus = LaundryOrderStatus.pending;
  Map<int, int> _selectedServiceAddOnQuantities = <int, int>{};
  Map<int, int> _baseServiceAddOnQuantities = <int, int>{};
  Map<int, int> _selectedPaidAddOnQuantities = <int, int>{};
  String? _itemImagePath;
  File? _itemImageFile;
  String? _pickupProofImagePath;
  File? _pickupProofImageFile;
  double _addOnTotal = 0;
  bool _isSaving = false;
  LaundryOrder? _editingOrder;

  @override
  void initState() {
    super.initState();
    _ordersFuture = LaundryService.instance.getOrders();
    unawaited(_loadLookups());
    _laundryAmountController.addListener(_recomputeTotals);
    _amountPaidController.addListener(_recomputeTotals);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerLookupController.dispose();
    _paidAddOnLookupController.dispose();
    _walkInNameController.dispose();
    _customerContactController.dispose();
    _weightController.dispose();
    _clothesCountController.dispose();
    _laundryAmountController.dispose();
    _totalAmountDueController.dispose();
    _amountPaidController.dispose();
    _balanceDueController.dispose();
    _changeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() {
    final existingTask = _lookupLoadTask;
    if (existingTask != null) {
      return existingTask;
    }

    final task = () async {
      final results = await Future.wait([
        CustomerService.instance.getCustomers(),
        LaundryStockService.instance.getStockItems(),
        LaundryServiceItemService.instance.getServices(),
      ]);

      final customers = results[0] as List<Customer>;
      final stockItems = results[1] as List<LaundryStockItem>;
      final serviceItems = results[2] as List<LaundryServiceItem>;
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _availableAddOns = stockItems;
        _availableServices = serviceItems;
      });
    }();

    _lookupLoadTask = task.whenComplete(() {
      _lookupLoadTask = null;
    });
    return _lookupLoadTask!;
  }

  Future<void> _reload() async {
    setState(() {
      _ordersFuture = LaundryService.instance.getOrders();
    });
    await _loadLookups();
  }

  Customer? _findCustomerById(int? id) {
    if (id == null) return null;
    for (final customer in _customers) {
      if (customer.id == id) return customer;
    }
    return null;
  }

  List<Customer> get _filteredCustomers {
    if (_selectedCustomerId != null) return const [];
    final query = _customerLookupQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _customers
        .where((customer) => customer.name.toLowerCase().contains(query))
        .take(8)
        .toList();
  }

  List<LaundryStockItem> get _filteredAddOns {
    final query = _paidAddOnLookupQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _availableAddOns
        .where(
          (item) =>
              item.itemName.toLowerCase().contains(query) &&
              (item.id != null &&
                  !_selectedPaidAddOnQuantities.containsKey(item.id!)),
        )
        .take(30)
        .toList();
  }

  List<LaundryStockItem> get _selectedServiceAddOnItems {
    return _availableAddOns
        .where(
          (item) =>
              item.id != null &&
              _selectedServiceAddOnQuantities.containsKey(item.id!),
        )
        .toList();
  }

  List<LaundryStockItem> get _selectedPaidAddOnItems {
    return _availableAddOns
        .where(
          (item) =>
              item.id != null &&
              _selectedPaidAddOnQuantities.containsKey(item.id!),
        )
        .toList();
  }

  List<LaundryStockItem> get _selectedServiceAddOnsForSave {
    final expanded = <LaundryStockItem>[];
    for (final item in _selectedServiceAddOnItems) {
      final itemId = item.id;
      if (itemId == null) continue;
      final quantity = _selectedServiceAddOnQuantities[itemId] ?? 0;
      for (var i = 0; i < quantity; i++) {
        expanded.add(item);
      }
    }
    return expanded;
  }

  List<LaundryStockItem> get _selectedPaidAddOnsForSave {
    final expanded = <LaundryStockItem>[];
    for (final item in _selectedPaidAddOnItems) {
      final itemId = item.id;
      if (itemId == null) continue;
      final quantity = _selectedPaidAddOnQuantities[itemId] ?? 0;
      for (var i = 0; i < quantity; i++) {
        expanded.add(item);
      }
    }
    return expanded;
  }

  LaundryServiceItem? _findServiceById(int? id) {
    if (id == null) return null;
    for (final service in _availableServices) {
      if (service.id == id) return service;
    }
    return null;
  }

  Map<int, int> _defaultServiceAddOnQuantities(LaundryServiceItem service) {
    final rawIds = (service.addOnItemIds ?? '')
        .split(',')
        .map((raw) => int.tryParse(raw.trim()))
        .whereType<int>();
    final mapped = <int, int>{};
    for (final id in rawIds) {
      mapped[id] = (mapped[id] ?? 0) + 1;
    }
    return mapped;
  }

  void _applySelectedService(
    int? serviceId,
    void Function(void Function()) setDialogState,
  ) {
    final service = _findServiceById(serviceId);
    setDialogState(() {
      _selectedServiceId = service?.id;
      _selectedServiceName = service?.name;
      _baseServiceAddOnQuantities = service == null
          ? <int, int>{}
          : _defaultServiceAddOnQuantities(service);
      _applyServiceScalingByWeight();
    });
  }

  void _applyServiceScalingByWeight() {
    final service = _findServiceById(_selectedServiceId);
    if (service == null) {
      _selectedServiceAddOnQuantities = <int, int>{};
      _laundryAmountController.text = '0.00';
      _recomputeTotals();
      return;
    }

    final weightKg = double.tryParse(_weightController.text.trim()) ?? 0;
    final maxWeightKg = service.maxWeightKg > 0 ? service.maxWeightKg : 1;
    final units = weightKg > 0 ? (weightKg / maxWeightKg).ceil() : 1;
    final multiplier = math.max(1, units);

    final scaledAddOns = <int, int>{};
    for (final entry in _baseServiceAddOnQuantities.entries) {
      scaledAddOns[entry.key] = entry.value * multiplier;
    }
    _selectedServiceAddOnQuantities = scaledAddOns;
    _laundryAmountController.text =
        (service.price * multiplier).toStringAsFixed(2);
    _recomputeTotals();
  }

  void _recomputeTotals() {
    final laundryAmount =
        double.tryParse(_laundryAmountController.text.trim()) ?? 0;
    final amountPaid = double.tryParse(_amountPaidController.text.trim()) ?? 0;
    final addOnTotal = _selectedPaidAddOnItems.fold<double>(0, (sum, item) {
      final itemId = item.id;
      final quantity =
          itemId == null ? 0 : (_selectedPaidAddOnQuantities[itemId] ?? 0);
      return sum + (item.retailPrice * quantity);
    });
    final totalDue = laundryAmount + addOnTotal;
    final balanceDue =
        (totalDue - amountPaid) > 0 ? (totalDue - amountPaid) : 0;
    final change = (amountPaid - totalDue) > 0 ? (amountPaid - totalDue) : 0;

    _addOnTotal = addOnTotal;
    _totalAmountDueController.text = totalDue.toStringAsFixed(2);
    _balanceDueController.text = balanceDue.toStringAsFixed(2);
    _changeController.text = change.toStringAsFixed(2);
  }

  void _setPaidAddOnQuantity(int itemId, int quantity) {
    if (quantity <= 0) {
      _selectedPaidAddOnQuantities.remove(itemId);
      return;
    }
    _selectedPaidAddOnQuantities[itemId] = quantity;
  }

  Future<void> _pickItemImage({
    required bool fromCamera,
    void Function(void Function())? setDialogState,
  }) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return;

    final setStateFn = setDialogState ?? setState;
    setStateFn(() {
      _itemImagePath = picked.path;
      _itemImageFile = File(picked.path);
    });
  }

  Future<void> _pickPickupProof({
    required bool fromCamera,
    void Function(void Function())? setDialogState,
  }) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );
    if (picked == null) return;

    final setStateFn = setDialogState ?? setState;
    setStateFn(() {
      _pickupProofImagePath = picked.path;
      _pickupProofImageFile = File(picked.path);
    });
  }

  void _prepareDialogState({LaundryOrder? order}) {
    _editingOrder = order;

    if (order == null) {
      _selectedCustomerId = null;
      _selectedServiceId = null;
      _selectedServiceName = null;
      _selectedStatus = LaundryOrderStatus.pending;
      _selectedServiceAddOnQuantities = <int, int>{};
      _baseServiceAddOnQuantities = <int, int>{};
      _selectedPaidAddOnQuantities = <int, int>{};
      _customerLookupQuery = '';
      _paidAddOnLookupQuery = '';
      _customerLookupController.clear();
      _paidAddOnLookupController.clear();
      _itemImagePath = null;
      _itemImageFile = null;
      _pickupProofImagePath = null;
      _pickupProofImageFile = null;

      _walkInNameController.clear();
      _customerContactController.clear();
      _weightController.text = '0';
      _clothesCountController.text = '0';
      _laundryAmountController.text = '0';
      _totalAmountDueController.text = '0';
      _amountPaidController.text = '0';
      _changeController.text = '0';
      _notesController.clear();
      _recomputeTotals();
      return;
    }

    _selectedCustomerId = order.customerId;
    _selectedServiceId = order.serviceId;
    _selectedServiceName = order.serviceName;
    _selectedStatus = order.status;
    final loadedFreeIds = (order.serviceAddOnItemIds ?? '')
        .split(',')
        .map((raw) => int.tryParse(raw.trim()))
        .whereType<int>();
    final freeQuantities = <int, int>{};
    for (final itemId in loadedFreeIds) {
      freeQuantities[itemId] = (freeQuantities[itemId] ?? 0) + 1;
    }
    _selectedServiceAddOnQuantities = freeQuantities;
    _baseServiceAddOnQuantities = freeQuantities;

    final loadedPaidIds = (order.paidAddOnItemIds ?? order.addOnItemIds ?? '')
        .split(',')
        .map((raw) => int.tryParse(raw.trim()))
        .whereType<int>();
    final paidQuantities = <int, int>{};
    for (final itemId in loadedPaidIds) {
      paidQuantities[itemId] = (paidQuantities[itemId] ?? 0) + 1;
    }
    _selectedPaidAddOnQuantities = paidQuantities;

    final selectedCustomer = _findCustomerById(_selectedCustomerId);
    final lookupName = selectedCustomer?.name ?? order.customerName;
    _customerLookupController.text = lookupName;
    _customerLookupQuery = '';
    _paidAddOnLookupController.clear();
    _paidAddOnLookupQuery = '';

    _itemImagePath = order.itemImagePath;
    _itemImageFile =
        order.itemImagePath == null ? null : File(order.itemImagePath!);
    _pickupProofImagePath = order.pickupProofImagePath;
    _pickupProofImageFile = order.pickupProofImagePath == null
        ? null
        : File(order.pickupProofImagePath!);

    _walkInNameController.text = order.customerName;
    _customerContactController.text = order.customerContact ?? '';
    _weightController.text = order.weightKg.toString();
    _clothesCountController.text = order.clothesCount.toString();
    final selectedService = _findServiceById(_selectedServiceId);
    if (selectedService != null) {
      _selectedServiceName = selectedService.name;
      _baseServiceAddOnQuantities = _defaultServiceAddOnQuantities(selectedService);
      _applyServiceScalingByWeight();
    } else {
      _laundryAmountController.text =
          order.laundryBaseAmount.toStringAsFixed(2);
    }
    _totalAmountDueController.text = order.amountPayable.toStringAsFixed(2);
    _amountPaidController.text = order.amountPaid.toString();
    _changeController.text = order.changeAmount.toStringAsFixed(2);
    _notesController.text = order.notes ?? '';

    if (selectedService == null) {
      _recomputeTotals();
    }
  }

  Future<void> _showOrderDialog({LaundryOrder? order}) async {
    if (_customers.isEmpty || _availableServices.isEmpty) {
      await _loadLookups();
    }
    if (_availableServices.isEmpty) {
      AppNotice.warning(
        'Please add at least one laundry service in Stock & service setup first.',
      );
      return;
    }
    if (!mounted) return;

    _prepareDialogState(order: order);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredCustomers = _filteredCustomers;
            final filteredAddOns = _filteredAddOns;
            final selectedCustomer = _findCustomerById(_selectedCustomerId);

            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 760, maxHeight: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order == null
                            ? 'Add laundry order'
                            : 'Edit laundry order',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextFormField(
                                  controller: _customerLookupController,
                                  decoration: const InputDecoration(
                                    labelText: 'Search customer by name',
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Type to find existing customers',
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _customerLookupQuery = value;
                                      _selectedCustomerId = null;
                                    });
                                  },
                                ),
                                if (filteredCustomers.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: SizedBox(
                                      height: 180,
                                      child: ListView.builder(
                                        itemCount: filteredCustomers.length,
                                        itemBuilder: (context, index) {
                                          final customer =
                                              filteredCustomers[index];
                                          return ListTile(
                                            dense: true,
                                            title: Text(customer.name),
                                            subtitle: Text(
                                              customer.contactNumber
                                                          ?.isNotEmpty ==
                                                      true
                                                  ? customer.contactNumber!
                                                  : 'No contact number',
                                            ),
                                            onTap: () {
                                              setDialogState(() {
                                                _selectedCustomerId =
                                                    customer.id;
                                                _customerLookupController.text =
                                                    customer.name;
                                                _customerLookupQuery = '';
                                                _walkInNameController.text =
                                                    customer.name;
                                                _customerContactController
                                                        .text =
                                                    customer.contactNumber ??
                                                        '';
                                              });
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                                if (selectedCustomer != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer
                                          .withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.verified_user,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Using existing customer: ${selectedCustomer.name}',
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            setDialogState(() {
                                              _selectedCustomerId = null;
                                              _customerLookupController.clear();
                                              _customerLookupQuery = '';
                                            });
                                          },
                                          child: const Text('Clear'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedServiceId,
                                  decoration: const InputDecoration(
                                    labelText: 'Laundry service',
                                  ),
                                  items: _availableServices
                                      .where((service) => service.id != null)
                                      .map(
                                        (service) => DropdownMenuItem<int>(
                                          value: service.id!,
                                          child: Text(
                                            '${service.name} - P ${service.price.toStringAsFixed(2)}',
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  validator: (value) => value == null
                                      ? 'Select a service.'
                                      : null,
                                  onChanged: (value) => _applySelectedService(
                                      value, setDialogState),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _walkInNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer name',
                                  ),
                                  validator: (value) {
                                    if (_selectedCustomerId != null) {
                                      return null;
                                    }
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter customer name when no customer is selected.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _customerContactController,
                                  decoration: const InputDecoration(
                                    labelText: 'Customer contact number',
                                  ),
                                  validator: (value) {
                                    if (_selectedCustomerId != null) {
                                      return null;
                                    }
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Enter customer contact when no customer is selected.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Item photo at drop-off',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickItemImage(
                                          fromCamera: true,
                                          setDialogState: setDialogState,
                                        ),
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text('Take photo'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _pickItemImage(
                                          fromCamera: false,
                                          setDialogState: setDialogState,
                                        ),
                                        icon: const Icon(Icons.photo_library),
                                        label: const Text('Choose photo'),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_itemImageFile != null) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _itemImageFile!,
                                      height: 140,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _weightController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Weight (kg)',
                                        ),
                                        onChanged: (_) {
                                          setDialogState(() {
                                            _applyServiceScalingByWeight();
                                          });
                                        },
                                        validator: (value) => value == null ||
                                                value.trim().isEmpty
                                            ? 'Enter weight.'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _clothesCountController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'No. of clothes',
                                        ),
                                        validator: (value) => value == null ||
                                                value.trim().isEmpty
                                            ? 'Enter clothes count.'
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Service add-ons (free)',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Automatically applied from selected service.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                if (_selectedServiceAddOnItems.isEmpty)
                                  const Text('- None')
                                else
                                  ..._selectedServiceAddOnItems.map(
                                    (item) {
                                      final quantity =
                                          _selectedServiceAddOnQuantities[
                                                  item.id] ??
                                              0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child:
                                            Text('${item.itemName} x$quantity'),
                                      );
                                    },
                                  ),
                                if (_selectedServiceId != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Service price and free add-ons auto-scale by weight.',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Text(
                                  'Additional add-ons (with charge)',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'These are charged and added to service amount.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _paidAddOnLookupController,
                                  decoration: const InputDecoration(
                                    labelText: 'Search paid add-ons',
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Type add-on name then tap item',
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _paidAddOnLookupQuery = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                if (_availableAddOns.isEmpty)
                                  const Text(
                                    'No laundry stock items available for add-ons.',
                                  )
                                else ...[
                                  if (filteredAddOns.isNotEmpty)
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: SizedBox(
                                        height: 180,
                                        child: ListView.builder(
                                          itemCount: filteredAddOns.length,
                                          itemBuilder: (context, index) {
                                            final item = filteredAddOns[index];
                                            final itemId = item.id;
                                            if (itemId == null) {
                                              return const SizedBox.shrink();
                                            }
                                            return ListTile(
                                              dense: true,
                                              title: Text(item.itemName),
                                              subtitle: Text(
                                                'P ${item.retailPrice.toStringAsFixed(2)} | ${item.stockNumber.isEmpty ? 'No stock code' : item.stockNumber}',
                                              ),
                                              trailing: const Icon(Icons.add),
                                              onTap: () {
                                                setDialogState(() {
                                                  _setPaidAddOnQuantity(
                                                    itemId,
                                                    (_selectedPaidAddOnQuantities[
                                                                itemId] ??
                                                            0) +
                                                        1,
                                                  );
                                                  _paidAddOnLookupController
                                                      .clear();
                                                  _paidAddOnLookupQuery = '';
                                                  _recomputeTotals();
                                                });
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  if (_paidAddOnLookupQuery.trim().isNotEmpty &&
                                      filteredAddOns.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text('No matching add-ons found.'),
                                    ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Selected paid add-ons',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  if (_selectedPaidAddOnItems.isEmpty)
                                    const Text('- None')
                                  else
                                    ..._selectedPaidAddOnItems.map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${item.itemName} (P ${item.retailPrice.toStringAsFixed(2)})',
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                final itemId = item.id;
                                                if (itemId == null) return;
                                                setDialogState(() {
                                                  final currentQty =
                                                      _selectedPaidAddOnQuantities[
                                                              itemId] ??
                                                          1;
                                                  _setPaidAddOnQuantity(
                                                      itemId, currentQty - 1);
                                                  _recomputeTotals();
                                                });
                                              },
                                              icon: const Icon(
                                                  Icons.remove_circle_outline),
                                              tooltip: 'Decrease quantity',
                                            ),
                                            SizedBox(
                                              width: 56,
                                              child: TextFormField(
                                                key: ValueKey(
                                                    'paid-qty-${item.id}-${_selectedPaidAddOnQuantities[item.id] ?? 0}'),
                                                initialValue:
                                                    (_selectedPaidAddOnQuantities[
                                                                item.id] ??
                                                            1)
                                                        .toString(),
                                                textAlign: TextAlign.center,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration:
                                                    const InputDecoration(
                                                  isDense: true,
                                                  contentPadding:
                                                      EdgeInsets.symmetric(
                                                          vertical: 8,
                                                          horizontal: 6),
                                                ),
                                                onChanged: (value) {
                                                  final itemId = item.id;
                                                  if (itemId == null) return;
                                                  final qty = int.tryParse(
                                                      value.trim());
                                                  if (qty == null) return;
                                                  setDialogState(() {
                                                    _setPaidAddOnQuantity(
                                                        itemId, qty);
                                                    _recomputeTotals();
                                                  });
                                                },
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                final itemId = item.id;
                                                if (itemId == null) return;
                                                setDialogState(() {
                                                  final currentQty =
                                                      _selectedPaidAddOnQuantities[
                                                              itemId] ??
                                                          0;
                                                  _setPaidAddOnQuantity(
                                                      itemId, currentQty + 1);
                                                  _recomputeTotals();
                                                });
                                              },
                                              icon: const Icon(
                                                  Icons.add_circle_outline),
                                              tooltip: 'Increase quantity',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'Additional add-ons total: P ${_addOnTotal.toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _laundryAmountController,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Service price',
                                        ),
                                        validator: (value) => value == null ||
                                                value.trim().isEmpty
                                            ? 'Enter laundry amount.'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _totalAmountDueController,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Total amount due',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _amountPaidController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Amount paid',
                                        ),
                                        validator: (value) => value == null ||
                                                value.trim().isEmpty
                                            ? 'Enter amount paid.'
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _changeController,
                                        readOnly: true,
                                        decoration: const InputDecoration(
                                            labelText: 'Change'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _balanceDueController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Balance due (auto-calculated)',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                DropdownButtonFormField<LaundryOrderStatus>(
                                  initialValue: _selectedStatus,
                                  decoration: const InputDecoration(
                                      labelText: 'Status'),
                                  items: LaundryOrderStatus.values
                                      .map(
                                        (status) => DropdownMenuItem<
                                            LaundryOrderStatus>(
                                          value: status,
                                          child: Text(
                                            LaundryService.instance
                                                .getStatusLabel(
                                              status,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _selectedStatus =
                                          value ?? LaundryOrderStatus.pending;
                                    });
                                  },
                                ),
                                if (_selectedStatus ==
                                    LaundryOrderStatus.pickedUp) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'Pickup proof image',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _pickPickupProof(
                                            fromCamera: true,
                                            setDialogState: setDialogState,
                                          ),
                                          icon: const Icon(Icons.camera_alt),
                                          label: const Text('Take photo'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _pickPickupProof(
                                            fromCamera: false,
                                            setDialogState: setDialogState,
                                          ),
                                          icon: const Icon(Icons.photo_library),
                                          label: const Text('Choose photo'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_pickupProofImageFile != null) ...[
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        _pickupProofImageFile!,
                                        height: 140,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _notesController,
                                  maxLines: 3,
                                  decoration:
                                      const InputDecoration(labelText: 'Notes'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _saveOrder(dialogContext),
                            icon: const Icon(Icons.save),
                            label: Text(
                                order == null ? 'Add order' : 'Save changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showOrderViewDialog(LaundryOrder order) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final statusColor = _statusColor(order.status);
        return AlertDialog(
          title: Text('Order ${order.referenceNumber}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          LaundryService.instance.getStatusLabel(order.status),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        DateFormat('yyyy-MM-dd HH:mm').format(order.updatedAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Customer: ${order.customerName}'),
                  Text('Contact: ${order.customerContact ?? '-'}'),
                  Text('Service: ${order.serviceName ?? '-'}'),
                  Text('Weight: ${order.weightKg.toStringAsFixed(2)} kg'),
                  Text('Clothes: ${order.clothesCount}'),
                  Text('Service add-ons (free): ${order.serviceAddOns ?? '-'}'),
                  Text(
                    'Additional add-ons: ${order.paidAddOns ?? order.addOns ?? '-'}',
                  ),
                  Text(
                    'Payable: ${NumberFormat.currency(symbol: 'P ').format(order.amountPayable)}',
                  ),
                  Text(
                    'Paid: ${NumberFormat.currency(symbol: 'P ').format(order.amountPaid)}',
                  ),
                  Text(
                    'Change: ${NumberFormat.currency(symbol: 'P ').format(order.changeAmount)}',
                  ),
                  Text(
                    'Balance: ${NumberFormat.currency(symbol: 'P ').format(LaundryService.instance.getOutstandingBalance(order))}',
                  ),
                  if ((order.notes ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Notes: ${order.notes}'),
                  ],
                  if ((order.itemImagePath ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Drop-off item photo',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(order.itemImagePath!),
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  if ((order.pickupProofImagePath ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Pickup proof photo',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(order.pickupProofImagePath!),
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _showOrderDialog(order: order);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveOrder(BuildContext dialogContext) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      if (_editingOrder == null &&
          (_itemImagePath == null || _itemImagePath!.trim().isEmpty)) {
        throw ArgumentError('Please take a photo of the laundry items first.');
      }

      final weightKg = double.tryParse(_weightController.text.trim()) ?? 0;
      final clothesCount =
          int.tryParse(_clothesCountController.text.trim()) ?? 0;
      final laundryBaseAmount =
          double.tryParse(_laundryAmountController.text.trim()) ?? 0;
      final amountPaid =
          double.tryParse(_amountPaidController.text.trim()) ?? 0;
      final selectedService = _findServiceById(_selectedServiceId);
      final serviceName =
          selectedService?.name ?? (_selectedServiceName ?? '').trim();
      final serviceId = selectedService?.id;

      final selectedCustomer = _findCustomerById(_selectedCustomerId);
      final hasExistingCustomer = selectedCustomer != null;
      final customerId = hasExistingCustomer ? selectedCustomer.id : null;
      final customerName = hasExistingCustomer
          ? selectedCustomer.name
          : _walkInNameController.text.trim();
      final customerContact = hasExistingCustomer
          ? (selectedCustomer.contactNumber ?? '').trim()
          : _customerContactController.text.trim();

      if (_editingOrder == null) {
        await LaundryService.instance.addOrder(
          customerId: customerId,
          isWalkIn: !hasExistingCustomer,
          customerName: customerName,
          customerContact: customerContact,
          weightKg: weightKg,
          clothesCount: clothesCount,
          laundryBaseAmount: laundryBaseAmount,
          serviceId: serviceId,
          serviceName: serviceName,
          serviceAddOns: _selectedServiceAddOnsForSave,
          paidAddOns: _selectedPaidAddOnsForSave,
          amountPaid: amountPaid,
          status: _selectedStatus,
          itemImagePath: _itemImagePath,
          pickupProofImagePath: _pickupProofImagePath,
          notes: _notesController.text,
        );
      } else {
        await LaundryService.instance.updateOrder(
          id: _editingOrder!.id!,
          customerId: customerId,
          isWalkIn: !hasExistingCustomer,
          customerName: customerName,
          customerContact: customerContact,
          weightKg: weightKg,
          clothesCount: clothesCount,
          laundryBaseAmount: laundryBaseAmount,
          serviceId: serviceId,
          serviceName: serviceName,
          serviceAddOns: _selectedServiceAddOnsForSave,
          paidAddOns: _selectedPaidAddOnsForSave,
          amountPaid: amountPaid,
          status: _selectedStatus,
          itemImagePath: _itemImagePath,
          pickupProofImagePath: _pickupProofImagePath,
          notes: _notesController.text,
        );
      }

      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      await _reload();
      if (!mounted) return;
      AppNotice.success('Laundry order saved successfully.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteOrder(int id) async {
    try {
      await LaundryService.instance.deleteOrder(id);
      await _reload();
      if (!mounted) return;
      AppNotice.success('Laundry order archived. Restore anytime from Archives.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    }
  }

  Future<void> _showBalancePaymentDialog(LaundryOrder order) async {
    final orderId = order.id;
    if (orderId == null) return;

    final outstanding = LaundryService.instance.getOutstandingBalance(order);
    final controller =
        TextEditingController(text: outstanding.toStringAsFixed(2));
    final formKey = GlobalKey<FormState>();

    final paid = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Pay balance • ${order.referenceNumber}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Remaining balance: ${NumberFormat.currency(symbol: 'P ').format(outstanding)}',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Payment amount'),
                  validator: (value) {
                    final parsed = double.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid payment amount.';
                    }
                    if (parsed > outstanding) {
                      return 'Payment cannot exceed remaining balance.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Record payment'),
            ),
          ],
        );
      },
    );

    if (paid != true) return;

    try {
      final paymentAmount = double.tryParse(controller.text.trim()) ?? 0;
      await LaundryService.instance.recordBalancePayment(
        orderId: orderId,
        paymentAmount: paymentAmount,
      );
      await _reload();
      if (!mounted) return;
      AppNotice.success('Laundry balance payment recorded.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    }
  }

  Future<void> _confirmDeleteOrder(LaundryOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Archive laundry order?'),
          content: Text(
            'Archive ${order.referenceNumber} for ${order.customerName}? You can restore it from Archives.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && order.id != null) {
      await _deleteOrder(order.id!);
    }
  }

  Color _statusColor(LaundryOrderStatus status) {
    return switch (status) {
      LaundryOrderStatus.pending => const Color(0xFFF59E0B),
      LaundryOrderStatus.inProgress => const Color(0xFF2563EB),
      LaundryOrderStatus.readyForPickup => const Color(0xFF7C3AED),
      LaundryOrderStatus.pickedUp => const Color(0xFF059669),
    };
  }

  bool _matchesDateFilter(DateTime value) {
    final selected = _dateFilter;
    if (selected == null) return true;
    final local = value.toLocal();
    return local.year == selected.year &&
        local.month == selected.month &&
        local.day == selected.day;
  }

  Future<void> _pickDateFilter() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (selected == null || !mounted) return;
    setState(() => _dateFilter = selected);
  }

  Future<_LaundrySalesSnapshot> _getLaundrySalesSnapshot() async {
    final orders = await LaundryService.instance.getOrders();
    final now = DateTime.now().toLocal();
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final todayPaid = orders.where((order) {
      final createdAt = order.createdAt.toLocal();
      return !createdAt.isBefore(start) && !createdAt.isAfter(end);
    }).fold<double>(0, (sum, order) => sum + order.netReceived);

    final totalUnpaid = orders.fold<double>(0, (sum, order) {
      final outstanding = order.amountPayable - order.amountPaid;
      return sum + (outstanding > 0 ? outstanding : 0);
    });
    return _LaundrySalesSnapshot(todayPaid: todayPaid, totalUnpaid: totalUnpaid);
  }

  Widget _buildOrderCard(LaundryOrder order) {
    final outstanding = LaundryService.instance.getOutstandingBalance(order);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.customerName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text('Service: ${order.serviceName ?? '-'}'),
            Text(
              'Amount due: ${NumberFormat.currency(symbol: 'P ').format(order.amountPayable)}',
            ),
            Text(
              'Balance: ${NumberFormat.currency(symbol: 'P ').format(outstanding)}',
              style: TextStyle(
                color: outstanding > 0 ? const Color(0xFFB91C1C) : null,
                fontWeight: outstanding > 0 ? FontWeight.w600 : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showOrderViewDialog(order),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View'),
                  ),
                ),
                if (outstanding > 0 && order.id != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _showBalancePaymentDialog(order),
                      icon: const Icon(Icons.payments_rounded),
                      label: const Text('Pay balance'),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _confirmDeleteOrder(order),
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
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
      appBar: AppBar(title: const Text('Laundry management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showOrderDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add laundry order'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: FutureBuilder<_LaundrySalesSnapshot>(
              future: _getLaundrySalesSnapshot(),
              builder: (context, snapshot) {
                final summary = snapshot.data ?? const _LaundrySalesSnapshot();
                return Row(
                  children: [
                    Expanded(
                      child: _salesSummaryCard(
                        title: 'Today paid sales',
                        value: summary.todayPaid,
                        icon: Icons.today_rounded,
                        color: const Color(0xFF0EA5A4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _salesSummaryCard(
                        title: 'Unpaid balance',
                        value: summary.totalUnpaid,
                        icon: Icons.request_quote_rounded,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search customer/contact/ref',
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
                        onChanged: (value) {
                          setState(
                              () => _searchQuery = value.trim().toLowerCase());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 190,
                      child: DropdownButtonFormField<LaundryOrderStatus?>(
                        initialValue: _statusFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<LaundryOrderStatus?>(
                            value: null,
                            child: Text('All statuses'),
                          ),
                          ...LaundryOrderStatus.values.map(
                            (status) => DropdownMenuItem<LaundryOrderStatus?>(
                              value: status,
                              child: Text(LaundryService.instance
                                  .getStatusLabel(status)),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 185,
                      child: DropdownButtonFormField<_LaundryBalanceFilter>(
                        initialValue: _balanceFilter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Balance',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: _LaundryBalanceFilter.all,
                            child: Text('All'),
                          ),
                          DropdownMenuItem(
                            value: _LaundryBalanceFilter.withBalance,
                            child: Text('With balance'),
                          ),
                          DropdownMenuItem(
                            value: _LaundryBalanceFilter.fullyPaid,
                            child: Text('Fully paid'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _balanceFilter = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickDateFilter,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        _dateFilter == null
                            ? 'All dates'
                            : DateFormat('yyyy-MM-dd').format(_dateFilter!),
                      ),
                    ),
                    if (_dateFilter != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _dateFilter = null),
                        child: const Text('Clear date'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LaundryOrder>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }

                final orders = snapshot.data ?? const <LaundryOrder>[];
                final filtered = orders.where((order) {
                  final query = _searchQuery;
                  final matchesQuery = query.isEmpty ||
                      order.referenceNumber.toLowerCase().contains(query) ||
                      order.customerName.toLowerCase().contains(query) ||
                      (order.customerContact?.toLowerCase().contains(query) ??
                          false);
                  final matchesStatus =
                      _statusFilter == null || order.status == _statusFilter;
                  final hasBalance =
                      LaundryService.instance.getOutstandingBalance(order) > 0;
                  final matchesBalance = switch (_balanceFilter) {
                    _LaundryBalanceFilter.all => true,
                    _LaundryBalanceFilter.withBalance => hasBalance,
                    _LaundryBalanceFilter.fullyPaid => !hasBalance,
                  };
                  final matchesDate = _matchesDateFilter(order.createdAt);
                  return matchesQuery &&
                      matchesStatus &&
                      matchesBalance &&
                      matchesDate;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No laundry orders match the current filters.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      _buildOrderCard(filtered[index]),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesSummaryCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'P ${value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaundrySalesSnapshot {
  const _LaundrySalesSnapshot({this.todayPaid = 0, this.totalUnpaid = 0});

  final double todayPaid;
  final double totalUnpaid;
}
