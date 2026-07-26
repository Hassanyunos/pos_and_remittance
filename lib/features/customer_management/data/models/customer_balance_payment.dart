class CustomerBalancePayment {
  const CustomerBalancePayment({
    this.id,
    required this.customerId,
    this.saleId,
    required this.amount,
    required this.paymentType,
    this.note,
    required this.createdAt,
  });

  final int? id;
  final int customerId;
  final int? saleId;
  final double amount;
  final CustomerBalancePaymentType paymentType;
  final String? note;
  final DateTime createdAt;

  factory CustomerBalancePayment.fromMap(Map<String, Object?> map) => CustomerBalancePayment(
        id: map['id'] as int?,
        customerId: map['customer_id'] as int,
        saleId: map['sale_id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        paymentType: CustomerBalancePaymentTypeX.fromValue(map['payment_type'] as String?),
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'sale_id': saleId,
        'amount': amount,
        'payment_type': paymentType.value,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  CustomerBalancePayment copyWith({
    int? id,
    int? customerId,
    int? saleId,
    double? amount,
    CustomerBalancePaymentType? paymentType,
    String? note,
    DateTime? createdAt,
  }) => CustomerBalancePayment(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        saleId: saleId ?? this.saleId,
        amount: amount ?? this.amount,
        paymentType: paymentType ?? this.paymentType,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
}

enum CustomerBalancePaymentType { credit, payment }

extension CustomerBalancePaymentTypeX on CustomerBalancePaymentType {
  String get value {
    switch (this) {
      case CustomerBalancePaymentType.credit:
        return 'credit';
      case CustomerBalancePaymentType.payment:
        return 'payment';
    }
  }

  static CustomerBalancePaymentType fromValue(String? value) {
    switch (value) {
      case 'payment':
        return CustomerBalancePaymentType.payment;
      case 'credit':
      default:
        return CustomerBalancePaymentType.credit;
    }
  }
}
