import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../fund_management/data/models/fund.dart';
import '../../application/expense_service.dart';
import '../../data/models/expense.dart';

class ExpenseManagementPage extends StatefulWidget {
  const ExpenseManagementPage({super.key});

  @override
  State<ExpenseManagementPage> createState() => _ExpenseManagementPageState();
}

class _ExpenseManagementPageState extends State<ExpenseManagementPage> {
  List<Expense> _expenses = const [];
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
      final expenses = await ExpenseService.instance.getExpenses();
      final funds = await AppDatabase.instance.fundRepository!.getAll();
      if (!mounted) return;
      setState(() {
        _expenses = List<Expense>.from(expenses);
        _funds = funds;
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

  Future<void> _showExpenseForm([Expense? expense]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ExpenseEditorDialog(expense: expense, funds: _funds),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ExpenseService.instance.deleteExpense(expense.id!);
      await _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add expense'),
      ),
      body: _buildExpenseList(),
    );
  }

  Widget _buildExpenseList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) return Center(child: Text('Failed to load expenses: $_loadError'));
    if (_expenses.isEmpty) return const Center(child: Text('No expenses recorded yet.'));

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
              Icon(Icons.receipt_long_rounded, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Expense log', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Review all spending and adjust entries quickly.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._expenses.map((expense) => Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(expense.purpose),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent by: ${expense.personName}'),
                    Text('Amount: ${NumberFormat.currency(symbol: '₱').format(expense.amount)}'),
                    Text('Fund: ${_fundName(expense.fundId)}'),
                    Text('Date: ${DateFormat('MMM dd, yyyy hh:mm a').format(expense.expenseDate)}'),
                    if (expense.details != null && expense.details!.isNotEmpty) Text('Details: ${expense.details}'),
                    if (expense.notes != null && expense.notes!.isNotEmpty) Text('Notes: ${expense.notes}'),
                  ],
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => _showExpenseForm(expense)),
                    IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _deleteExpense(expense)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  String _fundName(int fundId) {
    for (final fund in _funds) {
      if (fund.id == fundId) return fund.name;
    }
    return 'Unknown';
  }
}

class _ExpenseEditorDialog extends StatefulWidget {
  const _ExpenseEditorDialog({this.expense, required this.funds});

  final Expense? expense;
  final List<Fund> funds;

  @override
  State<_ExpenseEditorDialog> createState() => _ExpenseEditorDialogState();
}

class _ExpenseEditorDialogState extends State<_ExpenseEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _personController;
  late final TextEditingController _purposeController;
  late final TextEditingController _detailsController;
  late final TextEditingController _notesController;
  late DateTime _expenseDate;
  late int? _selectedFundId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.expense?.amount.toStringAsFixed(2) ?? '0.00');
    _personController = TextEditingController(text: widget.expense?.personName ?? '');
    _purposeController = TextEditingController(text: widget.expense?.purpose ?? '');
    _detailsController = TextEditingController(text: widget.expense?.details ?? '');
    _notesController = TextEditingController(text: widget.expense?.notes ?? '');
    _expenseDate = widget.expense?.expenseDate ?? DateTime.now();
    _selectedFundId = widget.expense?.fundId ?? (widget.funds.isNotEmpty ? widget.funds.first.id : null);
  }

  Future<void> _pickDateTime() async {
    final currentContext = context;
    final pickedDate = await showDatePicker(
      context: currentContext,
      initialDate: _expenseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null) return;

    if (!mounted || !currentContext.mounted) return;

    final pickedTime = await showTimePicker(
      context: currentContext,
      initialTime: TimeOfDay.fromDateTime(_expenseDate),
    );
    if (pickedTime == null) return;

    setState(() {
      _expenseDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);

    try {
      if (widget.expense == null) {
        await ExpenseService.instance.addExpense(
          fundId: _selectedFundId!,
          amount: double.parse(_amountController.text),
          expenseDate: _expenseDate,
          personName: _personController.text,
          purpose: _purposeController.text,
          details: _detailsController.text,
          notes: _notesController.text,
        );
      } else {
        await ExpenseService.instance.updateExpense(
          id: widget.expense!.id!,
          fundId: _selectedFundId!,
          amount: double.parse(_amountController.text),
          expenseDate: _expenseDate,
          personName: _personController.text,
          purpose: _purposeController.text,
          details: _detailsController.text,
          notes: _notesController.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.expense == null ? 'Add expense' : 'Edit expense'),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount spent'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter amount.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedFundId,
                    decoration: const InputDecoration(labelText: 'Fund'),
                    items: widget.funds
                        .map((fund) => DropdownMenuItem<int>(
                              value: fund.id,
                              child: Text('${fund.name} (${fund.currentBalance.toStringAsFixed(2)})'),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedFundId = value),
                    validator: (value) => value == null ? 'Select a fund.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _personController,
                    decoration: const InputDecoration(labelText: 'Who took it'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter the person name.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _purposeController,
                    decoration: const InputDecoration(labelText: 'Purpose'),
                    validator: (value) => value == null || value.trim().isEmpty ? 'Enter the purpose.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Other details'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _isSaving ? null : _pickDateTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date and time'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MMM dd, yyyy hh:mm a').format(_expenseDate)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: _isSaving ? null : _save, child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
        ],
      );

  @override
  void dispose() {
    _amountController.dispose();
    _personController.dispose();
    _purposeController.dispose();
    _detailsController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
