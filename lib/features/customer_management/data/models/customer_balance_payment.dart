class CustomerBalancePayment {
  const CustomerBalancePayment({
    this.id,
    required this.customerId,
    this.saleId,
    this.laundryOrderId,
    required this.amount,
    required this.paymentType,
    this.source = CustomerBalancePaymentSource.grocery,
    this.note,
    required this.createdAt,
  });

  final int? id;
  final int customerId;
  final int? saleId;
  final int? laundryOrderId;
  final double amount;
  final CustomerBalancePaymentType paymentType;
  final CustomerBalancePaymentSource source;
  final String? note;
  final DateTime createdAt;

  factory CustomerBalancePayment.fromMap(Map<String, Object?> map) =>
      CustomerBalancePayment(
        id: map['id'] as int?,
        customerId: map['customer_id'] as int,
        saleId: map['sale_id'] as int?,
        laundryOrderId: map['laundry_order_id'] as int?,
        amount: (map['amount'] as num).toDouble(),
        paymentType: CustomerBalancePaymentTypeX.fromValue(
            map['payment_type'] as String?),
        source:
            CustomerBalancePaymentSourceX.fromValue(map['source'] as String?),
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'customer_id': customerId,
        'sale_id': saleId,
        'laundry_order_id': laundryOrderId,
        'amount': amount,
        'payment_type': paymentType.value,
        'source': source.value,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  CustomerBalancePayment copyWith({
    int? id,
    int? customerId,
    int? saleId,
    int? laundryOrderId,
    double? amount,
    CustomerBalancePaymentType? paymentType,
    CustomerBalancePaymentSource? source,
    String? note,
    DateTime? createdAt,
  }) =>
      CustomerBalancePayment(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        saleId: saleId ?? this.saleId,
        laundryOrderId: laundryOrderId ?? this.laundryOrderId,
        amount: amount ?? this.amount,
        paymentType: paymentType ?? this.paymentType,
        source: source ?? this.source,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
}

enum CustomerBalancePaymentType { credit, payment }

enum CustomerBalancePaymentSource { grocery, laundry }

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

extension CustomerBalancePaymentSourceX on CustomerBalancePaymentSource {
  String get value {
    switch (this) {
      case CustomerBalancePaymentSource.grocery:
        return 'grocery';
      case CustomerBalancePaymentSource.laundry:
        return 'laundry';
    }
  }

  static CustomerBalancePaymentSource fromValue(String? value) {
    switch (value) {
      case 'laundry':
        return CustomerBalancePaymentSource.laundry;
      case 'grocery':
      default:
        return CustomerBalancePaymentSource.grocery;
    }
  }
}
