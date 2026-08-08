import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/ui/app_notice.dart';
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
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _selectedFundFilterId;
  _ExpenseDateFilter _dateFilter = _ExpenseDateFilter.all;
  bool _showFilters = false;
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes, delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ExpenseService.instance.deleteExpense(expense.id!);
      await _reload();
    } catch (error) {
      if (mounted) {
        AppNotice.error(error.toString());
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Failed to load expenses: $_loadError',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final now = DateTime.now().toLocal();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final filteredExpenses = _expenses.where((expense) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          expense.personName.toLowerCase().contains(query) ||
          expense.purpose.toLowerCase().contains(query) ||
          (expense.notes?.toLowerCase().contains(query) ?? false) ||
          _fundName(expense.fundId).toLowerCase().contains(query);

      final matchesFund = _selectedFundFilterId == null ||
          expense.fundId == _selectedFundFilterId;

      final date = expense.expenseDate.toLocal();
      final dateOnly = DateTime(date.year, date.month, date.day);
      final matchesDate = switch (_dateFilter) {
        _ExpenseDateFilter.all => true,
        _ExpenseDateFilter.today => !dateOnly.isBefore(todayStart),
        _ExpenseDateFilter.thisWeek => !dateOnly.isBefore(weekStart),
        _ExpenseDateFilter.thisMonth => !dateOnly.isBefore(monthStart),
      };

      return matchesSearch && matchesFund && matchesDate;
    }).toList()
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    final filteredTotal =
        filteredExpenses.fold<double>(0, (sum, item) => sum + item.amount);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
                Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.insights_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expense analytics',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${filteredExpenses.length} result${filteredExpenses.length == 1 ? '' : 's'} • ${NumberFormat.currency(symbol: 'P ').format(filteredTotal)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(_showFilters ? 14 : 20),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _showFilters = !_showFilters);
                      },
                      icon: Icon(
                        _showFilters
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                      ),
                      label: Text(_showFilters ? 'Collapse' : 'Expand'),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: !_showFilters
                      ? const SizedBox.shrink()
                      : Column(
                          key: const ValueKey('filter-open'),
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText:
                                    'Search person, purpose, note, or fund',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      ),
                              ),
                              onChanged: (value) => setState(() =>
                                  _searchQuery = value.trim().toLowerCase()),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int?>(
                              initialValue: _selectedFundFilterId,
                              decoration: const InputDecoration(
                                labelText: 'Fund',
                                isDense: true,
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('All funds'),
                                ),
                                ..._funds.map(
                                  (fund) => DropdownMenuItem<int?>(
                                    value: fund.id,
                                    child: Text(fund.name),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _selectedFundFilterId = value),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _dateChip('All time', _ExpenseDateFilter.all),
                                _dateChip('Today', _ExpenseDateFilter.today),
                                _dateChip(
                                    'This week', _ExpenseDateFilter.thisWeek),
                                _dateChip(
                                  'This month',
                                  _ExpenseDateFilter.thisMonth,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedFundFilterId = null;
                                      _dateFilter = _ExpenseDateFilter.all;
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all),
                                  label: const Text('Reset'),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: filteredExpenses.isEmpty
              ? Card(
                  key: const ValueKey('empty-state'),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.filter_alt_off_rounded,
                            size: 36,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 10),
                          const Text('No expenses match current filters.'),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  key: const ValueKey('list-state'),
                  children: filteredExpenses.asMap().entries.map((entry) {
                    final index = entry.key;
                    final expense = entry.value;
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 250 + (index * 35)),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 14),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer,
                                        borderRadius: BorderRadius.circular(9),
                                      ),
                                      child: Icon(
                                        Icons.receipt_long_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        expense.purpose,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      NumberFormat.currency(symbol: 'P ')
                                          .format(expense.amount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Spent by: ${expense.personName}'),
                                Text('Fund: ${_fundName(expense.fundId)}'),
                                Text(
                                  'Date: ${DateFormat('MMM dd, yyyy hh:mm a').format(expense.expenseDate)}',
                                ),
                                if (expense.notes != null &&
                                    expense.notes!.isNotEmpty)
                                  Text('Notes: ${expense.notes}'),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded),
                                      tooltip: 'Edit',
                                      onPressed: () =>
                                          _showExpenseForm(expense),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                          Icons.delete_outline_rounded),
                                      tooltip: 'Delete',
                                      onPressed: () => _deleteExpense(expense),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _dateChip(String label, _ExpenseDateFilter value) {
    return ChoiceChip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Text(label),
      selected: _dateFilter == value,
      onSelected: (_) {
        setState(() => _dateFilter = value);
      },
      avatar: _dateFilter == value ? const Icon(Icons.check, size: 16) : null,
    );
  }

  String _fundName(int fundId) {
    for (final fund in _funds) {
      if (fund.id == fundId) return fund.name;
    }
    return 'Unknown';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

enum _ExpenseDateFilter { all, today, thisWeek, thisMonth }

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
  late final TextEditingController _notesController;
  late DateTime _expenseDate;
  late int? _selectedFundId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.expense?.amount.toStringAsFixed(2) ?? '0.00');
    _personController =
        TextEditingController(text: widget.expense?.personName ?? '');
    _purposeController =
        TextEditingController(text: widget.expense?.purpose ?? '');
    _notesController = TextEditingController(text: widget.expense?.notes ?? '');
    _expenseDate = widget.expense?.expenseDate ?? DateTime.now();
    _selectedFundId = widget.expense?.fundId ??
        (widget.funds.isNotEmpty ? widget.funds.first.id : null);
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
          notes: _notesController.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppNotice.error(error.toString());
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Amount spent'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter amount.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedFundId,
                    decoration: const InputDecoration(labelText: 'Fund'),
                    items: widget.funds
                        .map((fund) => DropdownMenuItem<int>(
                              value: fund.id,
                              child: Text(
                                  '${fund.name} (${fund.currentBalance.toStringAsFixed(2)})'),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFundId = value),
                    validator: (value) =>
                        value == null ? 'Select a fund.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _personController,
                    decoration: const InputDecoration(labelText: 'Who took it'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the person name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _purposeController,
                    decoration: const InputDecoration(labelText: 'Purpose'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the purpose.'
                        : null,
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
                      decoration:
                          const InputDecoration(labelText: 'Date and time'),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('MMM dd, yyyy hh:mm a')
                              .format(_expenseDate)),
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
          TextButton(
              onPressed:
                  _isSaving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save')),
        ],
      );

  @override
  void dispose() {
    _amountController.dispose();
    _personController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
