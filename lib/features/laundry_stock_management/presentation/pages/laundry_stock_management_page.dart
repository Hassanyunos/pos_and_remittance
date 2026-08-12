import 'package:flutter/material.dart';

import '../../../../core/ui/app_notice.dart';
import '../../application/laundry_service_item_service.dart';
import '../../application/laundry_stock_service.dart';
import '../../data/models/laundry_service_item.dart';
import '../../data/models/laundry_stock_item.dart';

enum _LaundryCatalogSection { stock, service }

class LaundryStockManagementPage extends StatefulWidget {
  const LaundryStockManagementPage({super.key});

  @override
  State<LaundryStockManagementPage> createState() =>
      _LaundryStockManagementPageState();
}

class _LaundryStockManagementPageState
    extends State<LaundryStockManagementPage> {
  late Future<_LaundryCatalogData> _catalogFuture;

  final _stockFormKey = GlobalKey<FormState>();
  final _serviceFormKey = GlobalKey<FormState>();

  final _itemNameController = TextEditingController();
  final _stockNumberController = TextEditingController();
  final _stockQuantityController = TextEditingController();
  final _capitalPriceController = TextEditingController();
  final _retailPriceController = TextEditingController();
  final _notesController = TextEditingController();

  final _serviceNameController = TextEditingController();
  final _servicePriceController = TextEditingController();
  final _serviceMaxWeightController = TextEditingController(text: '1');
  final _serviceNotesController = TextEditingController();
  final _serviceAddOnLookupController = TextEditingController();

  final _searchController = TextEditingController();

  _LaundryCatalogSection _section = _LaundryCatalogSection.stock;
  String _searchQuery = '';
  String _serviceAddOnLookupQuery = '';
  bool _isSaving = false;

  LaundryStockItem? _editingStock;
  LaundryServiceItem? _editingService;
  Map<int, int> _selectedServiceAddOnQuantities = <int, int>{};

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _stockNumberController.dispose();
    _stockQuantityController.dispose();
    _capitalPriceController.dispose();
    _retailPriceController.dispose();
    _notesController.dispose();
    _serviceNameController.dispose();
    _servicePriceController.dispose();
    _serviceMaxWeightController.dispose();
    _serviceNotesController.dispose();
    _serviceAddOnLookupController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<_LaundryCatalogData> _loadCatalog() async {
    final results = await Future.wait([
      LaundryStockService.instance.getStockItems(),
      LaundryServiceItemService.instance.getServices(),
    ]);
    return _LaundryCatalogData(
      stockItems: results[0] as List<LaundryStockItem>,
      serviceItems: results[1] as List<LaundryServiceItem>,
    );
  }

  Future<void> _refreshCatalog() async {
    setState(() {
      _catalogFuture = _loadCatalog();
    });
  }

  Future<void> _showStockDialog({LaundryStockItem? item}) async {
    _editingStock = item;

    if (item == null) {
      _itemNameController.clear();
      _stockNumberController.clear();
      _stockQuantityController.clear();
      _capitalPriceController.clear();
      _retailPriceController.clear();
      _notesController.clear();
    } else {
      _itemNameController.text = item.itemName;
      _stockNumberController.text = item.stockNumber;
      _stockQuantityController.text = item.quantityInStock.toString();
      _capitalPriceController.text = item.capitalPrice.toStringAsFixed(2);
      _retailPriceController.text = item.retailPrice.toStringAsFixed(2);
      _notesController.text = item.notes ?? '';
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title:
              Text(item == null ? 'Add laundry stock' : 'Edit laundry stock'),
          content: SingleChildScrollView(
            child: Form(
              key: _stockFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _itemNameController,
                    decoration: const InputDecoration(labelText: 'Item name'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter item name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stockNumberController,
                    decoration: const InputDecoration(labelText: 'Stock code'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _stockQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter stock quantity.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _capitalPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Capital'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter capital price.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _retailPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Retail'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter retail price.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: _isSaving ? null : () => _saveStock(dialogContext),
              icon: const Icon(Icons.save),
              label: Text(item == null ? 'Add stock' : 'Save changes'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveStock(BuildContext dialogContext) async {
    if (!(_stockFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final quantity = int.tryParse(_stockQuantityController.text.trim()) ?? 0;
      final capitalPrice =
          double.tryParse(_capitalPriceController.text.trim()) ?? 0;
      final retailPrice =
          double.tryParse(_retailPriceController.text.trim()) ?? 0;

      if (_editingStock == null) {
        await LaundryStockService.instance.addStockItem(
          itemName: _itemNameController.text,
          stockNumber: _stockNumberController.text,
          quantityInStock: quantity,
          capitalPrice: capitalPrice,
          retailPrice: retailPrice,
          minimumAlertQuantity: 0,
          category: 'Laundry',
          notes: _notesController.text,
        );
      } else {
        await LaundryStockService.instance.updateStockItem(
          id: _editingStock!.id!,
          itemName: _itemNameController.text,
          stockNumber: _stockNumberController.text,
          quantityInStock: quantity,
          capitalPrice: capitalPrice,
          retailPrice: retailPrice,
          minimumAlertQuantity: _editingStock!.minimumAlertQuantity,
          picturePath: _editingStock!.picturePath,
          category: _editingStock!.category,
          notes: _notesController.text,
        );
      }

      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      await _refreshCatalog();
      if (!mounted) return;
      AppNotice.success('Laundry stock saved successfully.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showServiceDialog(
    List<LaundryStockItem> stockItems, {
    LaundryServiceItem? service,
  }) async {
    _editingService = service;

    if (service == null) {
      _serviceNameController.clear();
      _servicePriceController.clear();
      _serviceMaxWeightController.text = '1';
      _serviceNotesController.clear();
      _serviceAddOnLookupController.clear();
      _serviceAddOnLookupQuery = '';
      _selectedServiceAddOnQuantities = <int, int>{};
    } else {
      _serviceNameController.text = service.name;
      _servicePriceController.text = service.price.toStringAsFixed(2);
      _serviceMaxWeightController.text =
          service.maxWeightKg.toStringAsFixed(2);
      _serviceNotesController.text = service.notes ?? '';
      _serviceAddOnLookupController.clear();
      _serviceAddOnLookupQuery = '';
      final parsed = (service.addOnItemIds ?? '')
          .split(',')
          .map((raw) => int.tryParse(raw.trim()))
          .whereType<int>();
      final quantities = <int, int>{};
      for (final id in parsed) {
        quantities[id] = (quantities[id] ?? 0) + 1;
      }
      _selectedServiceAddOnQuantities = quantities;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final lookup = _serviceAddOnLookupQuery.trim().toLowerCase();
            final filteredAddOns = lookup.isEmpty
                ? stockItems
                : stockItems
                    .where(
                        (item) => item.itemName.toLowerCase().contains(lookup))
                    .toList();

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
                        service == null
                            ? 'Add laundry service'
                            : 'Edit laundry service',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Form(
                            key: _serviceFormKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _serviceNameController,
                                  decoration: const InputDecoration(
                                      labelText: 'Service name'),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Enter service name.'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _servicePriceController,
                                  keyboardType: TextInputType.number,
                                  decoration:
                                      const InputDecoration(labelText: 'Price'),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Enter service price.'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _serviceMaxWeightController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Maximum weight (kg)',
                                    helperText:
                                        'Orders above this are auto-scaled by multiplier.',
                                  ),
                                  validator: (value) {
                                    final parsed =
                                        double.tryParse((value ?? '').trim());
                                    if (parsed == null || parsed <= 0) {
                                      return 'Enter a valid maximum weight.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _serviceAddOnLookupController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Search stock add-ons (optional)',
                                    prefixIcon: Icon(Icons.search),
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      _serviceAddOnLookupQuery = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Add-ons are free of charge and used for stock tracking.',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
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
                                    height: 220,
                                    child: filteredAddOns.isEmpty
                                        ? const Center(
                                            child: Text(
                                                'No matching stock items found.'),
                                          )
                                        : ListView.builder(
                                            itemCount: filteredAddOns.length,
                                            itemBuilder: (context, index) {
                                              final item =
                                                  filteredAddOns[index];
                                              final itemId = item.id;
                                              if (itemId == null) {
                                                return const SizedBox.shrink();
                                              }
                                              final quantity =
                                                  _selectedServiceAddOnQuantities[
                                                          itemId] ??
                                                      0;
                                              return ListTile(
                                                dense: true,
                                                title: Text(item.itemName),
                                                subtitle: Text(
                                                  item.stockNumber.isEmpty
                                                      ? 'No stock code'
                                                      : item.stockNumber,
                                                ),
                                                trailing: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          final next =
                                                              quantity - 1;
                                                          if (next <= 0) {
                                                            _selectedServiceAddOnQuantities
                                                                .remove(itemId);
                                                          } else {
                                                            _selectedServiceAddOnQuantities[
                                                                itemId] = next;
                                                          }
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 40,
                                                      child: Text(
                                                        '$quantity',
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          _selectedServiceAddOnQuantities[
                                                                  itemId] =
                                                              quantity + 1;
                                                        });
                                                      },
                                                      icon: const Icon(
                                                        Icons
                                                            .add_circle_outline,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _serviceNotesController,
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
                                : () => _saveService(dialogContext),
                            icon: const Icon(Icons.save),
                            label: Text(
                              service == null ? 'Add service' : 'Save changes',
                            ),
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

  Future<void> _saveService(BuildContext dialogContext) async {
    if (!(_serviceFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final price = double.tryParse(_servicePriceController.text.trim()) ?? 0;
      final maxWeightKg =
          double.tryParse(_serviceMaxWeightController.text.trim()) ?? 0;
      final addOnIds = <int>[];
      final sortedEntries = _selectedServiceAddOnQuantities.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sortedEntries) {
        for (var i = 0; i < entry.value; i++) {
          addOnIds.add(entry.key);
        }
      }

      if (_editingService == null) {
        await LaundryServiceItemService.instance.addService(
          name: _serviceNameController.text,
          price: price,
          maxWeightKg: maxWeightKg,
          addOnItemIds: addOnIds,
          notes: _serviceNotesController.text,
        );
      } else {
        await LaundryServiceItemService.instance.updateService(
          id: _editingService!.id!,
          name: _serviceNameController.text,
          price: price,
          maxWeightKg: maxWeightKg,
          addOnItemIds: addOnIds,
          notes: _serviceNotesController.text,
        );
      }

      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      await _refreshCatalog();
      if (!mounted) return;
      AppNotice.success('Laundry service saved successfully.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteStock(int id) async {
    try {
      await LaundryStockService.instance.deleteStockItem(id);
      await _refreshCatalog();
      if (!mounted) return;
      AppNotice.success('Laundry stock archived. Restore anytime from Archives.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    }
  }

  Future<void> _deleteService(int id) async {
    try {
      await LaundryServiceItemService.instance.deleteService(id);
      await _refreshCatalog();
      if (!mounted) return;
      AppNotice.success('Laundry service archived. Restore anytime from Archives.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    }
  }

  List<LaundryStockItem> _filterStockItems(List<LaundryStockItem> items) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      return item.itemName.toLowerCase().contains(query) ||
          item.stockNumber.toLowerCase().contains(query) ||
          (item.notes?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<LaundryServiceItem> _filterServiceItems(List<LaundryServiceItem> items) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      return item.name.toLowerCase().contains(query) ||
          (item.notes?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laundry stock and service management')),
      floatingActionButton: FutureBuilder<_LaundryCatalogData>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          final stockItems =
              snapshot.data?.stockItems ?? const <LaundryStockItem>[];
          return FloatingActionButton.extended(
            onPressed: () {
              if (_section == _LaundryCatalogSection.stock) {
                _showStockDialog();
              } else {
                _showServiceDialog(stockItems);
              }
            },
            icon: const Icon(Icons.add),
            label: Text(
              _section == _LaundryCatalogSection.stock
                  ? 'Add stock'
                  : 'Add service',
            ),
          );
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Stock'),
                    selected: _section == _LaundryCatalogSection.stock,
                    onSelected: (_) {
                      setState(() => _section = _LaundryCatalogSection.stock);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Service'),
                    selected: _section == _LaundryCatalogSection.service,
                    onSelected: (_) {
                      setState(() => _section = _LaundryCatalogSection.service);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _section == _LaundryCatalogSection.stock
                      ? 'Search stock by item name or code'
                      : 'Search services by name',
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
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim().toLowerCase()),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<_LaundryCatalogData>(
              future: _catalogFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }

                final catalog = snapshot.data ??
                    const _LaundryCatalogData(
                      stockItems: <LaundryStockItem>[],
                      serviceItems: <LaundryServiceItem>[],
                    );
                final stockById = {
                  for (final item in catalog.stockItems)
                    if (item.id != null) item.id!: item,
                };

                if (_section == _LaundryCatalogSection.stock) {
                  final stockItems = _filterStockItems(catalog.stockItems);
                  if (stockItems.isEmpty) {
                    return const Center(
                      child: Text(
                          'No laundry stock items match the current search.'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: stockItems.length,
                    itemBuilder: (context, index) {
                      final item = stockItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.itemName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.stockNumber.isEmpty
                                  ? 'No stock code'
                                  : item.stockNumber),
                              Text('Qty: ${item.quantityInStock}'),
                              Text(
                                  'Capital: P ${item.capitalPrice.toStringAsFixed(2)}'),
                              Text(
                                  'Retail: P ${item.retailPrice.toStringAsFixed(2)}'),
                              if ((item.notes ?? '').isNotEmpty)
                                Text('Notes: ${item.notes}'),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _showStockDialog(item: item),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                onPressed: item.id == null
                                    ? null
                                    : () => _deleteStock(item.id!),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                final services = _filterServiceItems(catalog.serviceItems);
                if (services.isEmpty) {
                  return const Center(
                    child:
                        Text('No laundry services match the current search.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    final addOnIds = (service.addOnItemIds ?? '')
                        .split(',')
                        .map((raw) => int.tryParse(raw.trim()))
                        .whereType<int>();
                    final quantities = <int, int>{};
                    for (final id in addOnIds) {
                      quantities[id] = (quantities[id] ?? 0) + 1;
                    }
                    final addOnNames = quantities.entries
                        .map((entry) {
                          final name = stockById[entry.key]?.itemName;
                          if (name == null) return null;
                          return '$name x${entry.value}';
                        })
                        .whereType<String>()
                        .join(', ');
                    return Card(
                      child: ListTile(
                        title: Text(service.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Price: P ${service.price.toStringAsFixed(2)}'),
                            Text(
                              'Max weight: ${service.maxWeightKg.toStringAsFixed(2)} kg',
                            ),
                            Text(
                              addOnNames.isEmpty
                                  ? 'Add-ons (free): None'
                                  : 'Add-ons (free): $addOnNames',
                            ),
                            if ((service.notes ?? '').isNotEmpty)
                              Text('Notes: ${service.notes}'),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _showServiceDialog(
                                  catalog.stockItems,
                                  service: service),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: service.id == null
                                  ? null
                                  : () => _deleteService(service.id!),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LaundryCatalogData {
  const _LaundryCatalogData({
    required this.stockItems,
    required this.serviceItems,
  });

  final List<LaundryStockItem> stockItems;
  final List<LaundryServiceItem> serviceItems;
}
