import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_notice.dart';
import '../../application/grocery_stock_category_service.dart';
import '../../application/grocery_stock_service.dart';
import '../../data/models/grocery_stock_category.dart';
import '../../data/models/grocery_stock_item.dart';

class GroceryStockManagementPage extends StatefulWidget {
  const GroceryStockManagementPage({super.key});

  @override
  State<GroceryStockManagementPage> createState() =>
      _GroceryStockManagementPageState();
}

class _GroceryStockManagementPageState
    extends State<GroceryStockManagementPage> {
  late Future<List<GroceryStockItem>> _stockItemsFuture;
  late Future<List<GroceryStockCategory>> _categoriesFuture;
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _stockNumberController = TextEditingController();
  final _quantityController = TextEditingController();
  final _capitalPriceController = TextEditingController();
  final _retailPriceController = TextEditingController();
  final _minimumAlertController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();

  DateTime? _selectedExpirationDate;
  String _searchQuery = '';
  String? _selectedCategoryFilter;
  String _selectedExpiryFilter = 'all';
  String _selectedStockFilter = 'all';
  String? _selectedImagePath;
  File? _selectedImageFile;
  bool _isSaving = false;
  GroceryStockItem? _editingItem;

  @override
  void initState() {
    super.initState();
    _stockItemsFuture = GroceryStockService.instance.getStockItems();
    _categoriesFuture = GroceryStockCategoryService.instance.getCategories();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _stockNumberController.dispose();
    _quantityController.dispose();
    _capitalPriceController.dispose();
    _retailPriceController.dispose();
    _minimumAlertController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshItems() async {
    setState(() {
      _stockItemsFuture = GroceryStockService.instance.getStockItems();
      _categoriesFuture = GroceryStockCategoryService.instance.getCategories();
    });
  }

  Future<void> _pickImage({required bool fromCamera}) async {
    final pickedFile = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery);
    if (pickedFile == null) return;
    setState(() {
      _selectedImageFile = File(pickedFile.path);
      _selectedImagePath = pickedFile.path;
    });
  }

  Future<void> _showItemDialog({GroceryStockItem? item}) async {
    _editingItem = item;
    if (item != null) {
      _itemNameController.text = item.itemName;
      _stockNumberController.text = item.stockNumber;
      _quantityController.text = item.quantityInStock.toString();
      _capitalPriceController.text = item.capitalPrice.toString();
      _retailPriceController.text = item.retailPrice.toString();
      _minimumAlertController.text = item.minimumAlertQuantity.toString();
      _categoryController.text = item.category;
      _notesController.text = item.notes ?? '';
      _selectedExpirationDate = item.expirationDate;
      _selectedImagePath = item.picturePath;
      _selectedImageFile =
          item.picturePath == null ? null : File(item.picturePath!);
    } else {
      _itemNameController.clear();
      _stockNumberController.clear();
      _quantityController.clear();
      _capitalPriceController.clear();
      _retailPriceController.clear();
      _minimumAlertController.clear();
      _categoryController.clear();
      _notesController.clear();
      _selectedExpirationDate = null;
      _selectedImagePath = null;
      _selectedImageFile = null;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(item == null ? 'Add stock item' : 'Edit stock item'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _itemNameController,
                        decoration:
                            const InputDecoration(labelText: 'Item name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter an item name.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _stockNumberController,
                        decoration: const InputDecoration(
                            labelText: 'Barcode (optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Stock quantity'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter stock quantity.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _capitalPriceController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Capital price'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter capital price.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _retailPriceController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Unit price'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter unit price.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _minimumAlertController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Minimum stock alert quantity'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter minimum alert quantity.'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<GroceryStockCategory>>(
                        future: _categoriesFuture,
                        builder: (context, snapshot) {
                          final categories =
                              snapshot.data ?? const <GroceryStockCategory>[];
                          final selectedCategory =
                              _categoryController.text.trim();
                          final uniqueCategories = <String>{'General'};
                          for (final category in categories) {
                            if (category.name.trim().isNotEmpty) {
                              uniqueCategories.add(category.name.trim());
                            }
                          }
                          if (selectedCategory.isNotEmpty) {
                            uniqueCategories.add(selectedCategory);
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCategory.isEmpty
                                      ? 'General'
                                      : selectedCategory,
                                  decoration: const InputDecoration(
                                      labelText: 'Category'),
                                  items: uniqueCategories
                                      .toList()
                                      .where((name) => name.isNotEmpty)
                                      .toList()
                                      .map((name) => DropdownMenuItem<String>(
                                          value: name, child: Text(name)))
                                      .toList(),
                                  onChanged: (value) => setDialogState(() =>
                                      _categoryController.text =
                                          value ?? 'General'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  final categoryName =
                                      await _showCategoryDialog();
                                  if (categoryName != null && mounted) {
                                    setDialogState(() {
                                      _categoryController.text = categoryName;
                                    });
                                  }
                                },
                                child: const Text('Add category'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Expiration date (optional)'),
                        subtitle: Text(_selectedExpirationDate == null
                            ? 'Not set'
                            : DateFormat('yyyy-MM-dd')
                                .format(_selectedExpirationDate!)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _selectedExpirationDate ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(
                                () => _selectedExpirationDate = picked);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
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
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel')),
                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _saveItem(dialogContext),
                  icon: const Icon(Icons.save),
                  label: Text(item == null ? 'Add item' : 'Save changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showCategoryDialog() async {
    final controller = TextEditingController();
    final categoryName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add category'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('Save')),
          ],
        );
      },
    );

    if (categoryName != null && categoryName.isNotEmpty) {
      await GroceryStockCategoryService.instance
          .addCategory(name: categoryName);
      await _refreshItems();
    }

    return categoryName;
  }

  Future<void> _saveItem(BuildContext dialogContext) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
      final capitalPrice =
          double.tryParse(_capitalPriceController.text.trim()) ?? 0;
      final retailPrice =
          double.tryParse(_retailPriceController.text.trim()) ?? 0;
      final minimumAlert =
          int.tryParse(_minimumAlertController.text.trim()) ?? 0;

      if (_editingItem == null) {
        await GroceryStockService.instance.addStockItem(
          itemName: _itemNameController.text,
          stockNumber: _stockNumberController.text,
          quantityInStock: quantity,
          capitalPrice: capitalPrice,
          retailPrice: retailPrice,
          minimumAlertQuantity: minimumAlert,
          picturePath: _selectedImagePath,
          category: _categoryController.text,
          expirationDate: _selectedExpirationDate,
          notes: _notesController.text,
        );
      } else {
        await GroceryStockService.instance.updateStockItem(
          id: _editingItem!.id!,
          itemName: _itemNameController.text,
          stockNumber: _stockNumberController.text,
          quantityInStock: quantity,
          capitalPrice: capitalPrice,
          retailPrice: retailPrice,
          minimumAlertQuantity: minimumAlert,
          picturePath: _selectedImagePath,
          category: _categoryController.text,
          expirationDate: _selectedExpirationDate,
          notes: _notesController.text,
        );
      }

      if (!mounted || !dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      await _refreshItems();
      if (!mounted) return;
      AppNotice.success('Stock item saved successfully.');
    } catch (e) {
      if (!mounted) return;
      AppNotice.error(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteItem(int id) async {
    try {
      await GroceryStockService.instance.deleteStockItem(id);
      await _refreshItems();
      if (mounted) {
        AppNotice.success('Stock item deleted.');
      }
    } catch (e) {
      if (mounted) {
        AppNotice.error(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grocery stock management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add stock'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or barcode',
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: FutureBuilder<List<GroceryStockCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                final categories =
                    snapshot.data ?? const <GroceryStockCategory>[];
                final categoryOptions = [
                  'all',
                  ...categories.map((category) => category.name)
                ];
                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedCategoryFilter ?? 'all',
                          decoration: const InputDecoration(
                              labelText: 'Category', isDense: true),
                          items: categoryOptions
                              .map((value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value == 'all'
                                      ? 'All categories'
                                      : value)))
                              .toList(),
                          onChanged: (value) => setState(() =>
                              _selectedCategoryFilter =
                                  value == 'all' ? null : value),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedExpiryFilter,
                          decoration: const InputDecoration(
                              labelText: 'Expiry', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                                value: 'expired', child: Text('Expired')),
                            DropdownMenuItem(
                                value: 'soon', child: Text('Expiring soon')),
                            DropdownMenuItem(
                                value: 'no-expiry', child: Text('No expiry')),
                          ],
                          onChanged: (value) => setState(
                              () => _selectedExpiryFilter = value ?? 'all'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedStockFilter,
                          decoration: const InputDecoration(
                              labelText: 'Stock', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                                value: 'low', child: Text('Low stock')),
                            DropdownMenuItem(
                                value: 'out', child: Text('Out of stock')),
                            DropdownMenuItem(
                                value: 'available', child: Text('Available')),
                          ],
                          onChanged: (value) => setState(
                              () => _selectedStockFilter = value ?? 'all'),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<GroceryStockItem>>(
              future: _stockItemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }

                final items = snapshot.data ?? const <GroceryStockItem>[];
                final filteredItems = items.where((item) {
                  final matchesQuery = _searchQuery.isEmpty ||
                      item.itemName.toLowerCase().contains(_searchQuery) ||
                      item.stockNumber.toLowerCase().contains(_searchQuery);
                  final matchesCategory = _selectedCategoryFilter == null ||
                      _selectedCategoryFilter!.isEmpty ||
                      item.category == _selectedCategoryFilter;
                  final matchesExpiry = switch (_selectedExpiryFilter) {
                    'expired' => item.expirationDate != null &&
                        item.expirationDate!.isBefore(DateTime.now()),
                    'soon' => item.expirationDate != null &&
                        !item.expirationDate!.isBefore(DateTime.now()) &&
                        item.expirationDate!
                                .difference(DateTime.now())
                                .inDays <=
                            30,
                    'no-expiry' => item.expirationDate == null,
                    _ => true,
                  };
                  final matchesStock = switch (_selectedStockFilter) {
                    'low' => item.quantityInStock <= item.minimumAlertQuantity,
                    'out' => item.quantityInStock <= 0,
                    'available' =>
                      item.quantityInStock > item.minimumAlertQuantity,
                    _ => true,
                  };
                  return matchesQuery &&
                      matchesCategory &&
                      matchesExpiry &&
                      matchesStock;
                }).toList();

                if (filteredItems.isEmpty) {
                  return const Center(
                      child: Text('No stock items match the current filters.'));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    ...filteredItems.map((item) {
                      final isOutOfStock = item.quantityInStock <= 0;
                      final isLowStock = item.quantityInStock > 0 &&
                          item.quantityInStock <= item.minimumAlertQuantity;
                      final isExpired = item.expirationDate != null &&
                          item.expirationDate!.isBefore(DateTime.now());
                      final isExpiringSoon = item.expirationDate != null &&
                          !item.expirationDate!.isBefore(DateTime.now()) &&
                          item.expirationDate!
                                  .difference(DateTime.now())
                                  .inDays <=
                              30;
                      final statusLabel = isExpired
                          ? 'expired'
                          : isExpiringSoon
                              ? 'expire-soon'
                              : isOutOfStock
                                  ? 'out-of-stock'
                                  : isLowStock
                                      ? 'low-stock'
                                      : '';
                      return Card(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          leading: item.picturePath != null
                              ? Image.file(File(item.picturePath!),
                                  width: 44, height: 44, fit: BoxFit.cover)
                              : const Icon(Icons.inventory_2, size: 36),
                          title: Text(
                            item.itemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.stockNumber.isEmpty
                                    ? 'No barcode'
                                    : item.stockNumber,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${item.quantityInStock} in stock • ${item.category}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Capital: ₱${item.capitalPrice.toStringAsFixed(2)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Unit price: ₱${item.retailPrice.toStringAsFixed(2)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.expirationDate != null)
                                Text(
                                  'Expiry: ${DateFormat('yyyy-MM-dd').format(item.expirationDate!)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 0),
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              runSpacing: 2,
                              children: [
                                if (statusLabel.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isExpired
                                          ? const Color(0xFFFFE5E5)
                                          : isExpiringSoon
                                              ? const Color(0xFFFFF1F0)
                                              : isOutOfStock
                                                  ? const Color(0xFFEAF3FF)
                                                  : const Color(0xFFFFF4E5),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isExpired
                                            ? const Color(0xFF8B0000)
                                            : isExpiringSoon
                                                ? Colors.red
                                                : isOutOfStock
                                                    ? Colors.blue
                                                    : Colors.orange,
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 28, minHeight: 28),
                                      onPressed: () =>
                                          _showItemDialog(item: item),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 28, minHeight: 28),
                                      onPressed: () => _deleteItem(item.id!),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
