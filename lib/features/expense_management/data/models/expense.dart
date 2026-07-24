class Expense {
  const Expense({
    this.id,
    required this.fundId,
    required this.amount,
    required this.expenseDate,
    required this.personName,
    required this.purpose,
    this.details,
    this.notes,
  });

  final int? id;
  final int fundId;
  final double amount;
  final DateTime expenseDate;
  final String personName;
  final String purpose;
  final String? details;
  final String? notes;

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int?,
        fundId: (map['fund_id'] as int?) ?? 1,
        amount: (map['amount'] as num).toDouble(),
        expenseDate: DateTime.parse(map['expense_date'] as String),
        personName: map['person_name'] as String,
        purpose: map['purpose'] as String,
        details: map['details'] as String?,
        notes: map['notes'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'fund_id': fundId,
        'amount': amount,
        'expense_date': expenseDate.toIso8601String(),
        'person_name': personName,
        'purpose': purpose,
        'details': details,
        'notes': notes,
      };

  Expense copyWith({
    int? id,
    int? fundId,
    double? amount,
    DateTime? expenseDate,
    String? personName,
    String? purpose,
    String? details,
    String? notes,
  }) => Expense(
        id: id ?? this.id,
        fundId: fundId ?? this.fundId,
        amount: amount ?? this.amount,
        expenseDate: expenseDate ?? this.expenseDate,
        personName: personName ?? this.personName,
        purpose: purpose ?? this.purpose,
        details: details ?? this.details,
        notes: notes ?? this.notes,
      );
}
