import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../auth/application/auth_service.dart';
import '../../application/fund_service.dart';
import '../../data/models/fund.dart';

class FundManagementPage extends StatefulWidget {
  const FundManagementPage({super.key});

  @override
  State<FundManagementPage> createState() => _FundManagementPageState();
}

class _FundManagementPageState extends State<FundManagementPage> {
  List<Fund> _funds = const [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final updatedFunds = await FundService.instance.getFunds();
      if (!mounted) return;
      setState(() {
        _funds = updatedFunds;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  Future<void> _showFundForm([Fund? fund]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FundEditorDialog(fund: fund),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _deleteFund(Fund fund) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fund?'),
        content: Text(
          'Are you sure you want to delete ${fund.name}? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await FundService.instance.deleteFund(fund.id!);
      await _reload();
    } on StateError catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(AuthService.instance.currentUser?.isOwner ?? false)) {
      return const Scaffold(body: Center(child: Text('Only the owner can manage funds.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Fund management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFundForm,
        icon: const Icon(Icons.add),
        label: const Text('Add fund'),
      ),
      body: _buildFundList(),
    );
  }

  Widget _buildFundList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return Center(child: Text('Failed to load funds: $_loadError'));
    if (_funds.isEmpty) return const Center(child: Text('No funds yet.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _funds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fund = _funds[index];
        return Card(
          child: ListTile(
            leading: Icon(fund.fundType == FundType.cash ? Icons.payments : Icons.account_balance_wallet),
            title: Text(fund.name),
            subtitle: Text(fund.fundType == FundType.cash ? 'Cash' : 'eCash'),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(NumberFormat.currency(symbol: '\u20B1').format(fund.currentBalance)),
                IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _showFundForm(fund)),
                IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _deleteFund(fund)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FundEditorDialog extends StatefulWidget {
  const _FundEditorDialog({this.fund});

  final Fund? fund;

  @override
  State<_FundEditorDialog> createState() => _FundEditorDialogState();
}

class _FundEditorDialogState extends State<_FundEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late FundType _type;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.fund?.name ?? '');
    _balanceController = TextEditingController(
      text: widget.fund?.currentBalance.toStringAsFixed(2) ?? '0.00',
    );
    _type = widget.fund?.fundType ?? FundType.cash;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      if (widget.fund == null) {
        await FundService.instance.addFund(
          name: _nameController.text,
          currentBalance: double.parse(_balanceController.text),
          fundType: _type,
        );
      } else {
        await FundService.instance.updateFund(
          id: widget.fund!.id!,
          name: _nameController.text,
          currentBalance: double.parse(_balanceController.text),
          fundType: _type,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.fund == null ? 'Add fund' : 'Edit fund'),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Fund name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a fund name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _balanceController,
                  decoration: const InputDecoration(labelText: 'Current balance'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => double.tryParse(value ?? '') == null
                      ? 'Enter a valid amount.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FundType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Fund type'),
                  items: FundType.values
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(item == FundType.cash ? 'Cash' : 'eCash'),
                          ))
                      .toList(),
                  onChanged: _isSaving ? null : (value) => setState(() => _type = value!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving ? const CircularProgressIndicator() : const Text('Save'),
          ),
        ],
      );

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }
}
