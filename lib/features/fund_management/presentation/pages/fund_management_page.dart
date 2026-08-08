import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_notice.dart';
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
  double _totalFundBalance = 0;
  double _totalGroceryCapital = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final updatedFunds = await FundService.instance.getFunds();
      final totalFundBalance = await FundService.instance.getTotalFundBalance();
      final totalGroceryCapital =
          await FundService.instance.getTotalGroceryCapital();
      if (!mounted) return;
      setState(() {
        _funds = updatedFunds;
        _totalFundBalance = totalFundBalance;
        _totalGroceryCapital = totalGroceryCapital;
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
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
      if (mounted) AppNotice.warning(error.message);
    }
  }

  Future<void> _showZakahDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const _ZakahDialog(),
    );
    if (confirmed == true && mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (!(AuthService.instance.currentUser?.isOwner ?? false)) {
      return const Scaffold(
          body: Center(child: Text('Only the owner can manage funds.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Fund management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFundForm,
        icon: const Icon(Icons.add),
        label: const Text('Add fund'),
      ),
      body: Stack(
        children: [
          _buildFundList(),
          Positioned(
            left: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _showZakahDialog,
              icon: const Icon(Icons.volunteer_activism),
              label: const Text('Take zakah'),
              heroTag: 'take_zakah_btn',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text('Failed to load funds: $_loadError'));
    }

    final itemCount = _funds.isEmpty ? 1 : _funds.length + 1;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Summary',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'Total funds: ${NumberFormat.currency(symbol: '₱').format(_totalFundBalance)}'),
                  Text(
                      'Total grocery stock capital: ${NumberFormat.currency(symbol: '₱').format(_totalGroceryCapital)}'),
                ],
              ),
            ),
          );
        }

        if (_funds.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('No funds yet.')),
          );
        }

        final fund = _funds[index - 1];
        return Card(
          child: ListTile(
            leading: Icon(fund.fundType == FundType.cash
                ? Icons.payments
                : Icons.account_balance_wallet),
            title: Text(fund.name),
            subtitle: Text(fund.fundType == FundType.cash ? 'Cash' : 'eCash'),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(NumberFormat.currency(symbol: '₱')
                    .format(fund.currentBalance)),
                IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit',
                    onPressed: () => _showFundForm(fund)),
                IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _deleteFund(fund)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZakahDialog extends StatefulWidget {
  const _ZakahDialog();

  @override
  State<_ZakahDialog> createState() => _ZakahDialogState();
}

class _ZakahDialogState extends State<_ZakahDialog> {
  final _formKey = GlobalKey<FormState>();
  final _goldController = TextEditingController(text: '0');
  final _silverController = TextEditingController(text: '0');
  bool _isSaving = false;
  bool _isCalculating = false;
  double? _calculatedAmount;
  String? _eligibilityMessage;
  int? _selectedFundId;
  List<Fund> _funds = const [];

  @override
  void initState() {
    super.initState();
    _goldController.addListener(_refreshCalculation);
    _silverController.addListener(_refreshCalculation);
    _loadFunds();
  }

  @override
  void dispose() {
    _goldController.removeListener(_refreshCalculation);
    _silverController.removeListener(_refreshCalculation);
    _goldController.dispose();
    _silverController.dispose();
    super.dispose();
  }

  Future<void> _loadFunds() async {
    try {
      final funds = await FundService.instance.getFunds();
      if (!mounted) return;
      setState(() {
        _funds = funds;
        if (_selectedFundId == null && funds.isNotEmpty) {
          _selectedFundId = funds.first.id;
        }
      });
      await _refreshCalculation();
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _refreshCalculation() async {
    final goldPrice = double.tryParse(_goldController.text);
    final silverPrice = double.tryParse(_silverController.text);

    if (goldPrice == null || silverPrice == null) {
      if (!mounted) return;
      setState(() => _calculatedAmount = null);
      return;
    }

    if (!mounted) return;
    setState(() => _isCalculating = true);

    try {
      final amount = await FundService.instance.getCurrentZakahAmount(
        goldPricePerGram: goldPrice,
        silverPricePerGram: silverPrice,
      );
      final eligibilityMessage =
          await FundService.instance.getCurrentZakatEligibilityMessage(
        goldPricePerGram: goldPrice,
        silverPricePerGram: silverPrice,
      );
      if (!mounted) return;
      setState(() {
        _calculatedAmount = amount;
        _eligibilityMessage =
            eligibilityMessage.isEmpty ? null : eligibilityMessage;
        _isCalculating = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _calculatedAmount = null;
        _eligibilityMessage = null;
        _isCalculating = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedFundId == null) {
      AppNotice.warning('Please choose a fund first.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FundService.instance.takeZakah(
        goldPricePerGram: double.parse(_goldController.text),
        silverPricePerGram: double.parse(_silverController.text),
        fundId: _selectedFundId!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      AppNotice.success('Zakat recorded successfully.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotice.error(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountText = _isCalculating
        ? 'Calculating zakah...'
        : _calculatedAmount == null
            ? 'Enter valid prices to calculate the zakah amount.'
            : 'Calculated zakah: ${NumberFormat.currency(symbol: '₱').format(_calculatedAmount)}';

    final displayMessage = _eligibilityMessage ?? amountText;

    return AlertDialog(
      title: const Text('Take zakah'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Zakat is only taken once a year. The amount is based on the total funds and grocery stock capital.'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _goldController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Gold price per gram'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a valid price.';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return 'Gold price must be greater than zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _silverController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Silver price per gram'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a valid price.';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) {
                    return 'Silver price must be greater than zero.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(displayMessage,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              if (_funds.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _selectedFundId,
                  decoration:
                      const InputDecoration(labelText: 'Deduct from fund'),
                  items: [
                    for (final fund in _funds)
                      DropdownMenuItem<int>(
                        value: fund.id,
                        child: Text(
                            '${fund.name} (${fund.fundType == FundType.cash ? 'Cash' : 'eCash'})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selectedFundId = value),
                )
              else
                const Text('No funds available to deduct from.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed:
                _isSaving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSaving ||
                  _calculatedAmount == null ||
                  _calculatedAmount! <= 0 ||
                  _eligibilityMessage != null ||
                  _selectedFundId == null
              ? null
              : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Take zakah'),
        ),
      ],
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
      AppNotice.warning(error.message);
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
                  decoration:
                      const InputDecoration(labelText: 'Current balance'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                            child:
                                Text(item == FundType.cash ? 'Cash' : 'eCash'),
                          ))
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _type = value!),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed:
                _isSaving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('Save'),
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
