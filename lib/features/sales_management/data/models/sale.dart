class Sale {
  const Sale({
    this.id,
    required this.receiptNumber,
    this.customerId,
    this.customerName,
    required this.totalPrice,
    required this.amountPayable,
    required this.amountPaid,
    required this.changeAmount,
    required this.soldAt,
    this.outstandingBalance = 0,
    this.isCreditSale = false,
  });

  final int? id;
  final String receiptNumber;
  final int? customerId;
  final String? customerName;
  final double totalPrice;
  final double amountPayable;
  final double amountPaid;
  final double changeAmount;
  final DateTime soldAt;
  final double outstandingBalance;
  final bool isCreditSale;

  factory Sale.fromMap(Map<String, Object?> map) => Sale(
        id: map['id'] as int?,
        receiptNumber: map['receipt_number'] as String,
        customerId: map['customer_id'] as int?,
        customerName: map['customer_name'] as String?,
        totalPrice: (map['total_price'] as num).toDouble(),
        amountPayable: (map['amount_payable'] as num).toDouble(),
        amountPaid: (map['amount_paid'] as num).toDouble(),
        changeAmount: (map['change_amount'] as num).toDouble(),
        soldAt: DateTime.parse(map['sold_at'] as String),
        outstandingBalance: (map['outstanding_balance'] as num?)?.toDouble() ?? 0,
        isCreditSale: (map['is_credit_sale'] as int?) == 1,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'receipt_number': receiptNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'total_price': totalPrice,
        'amount_payable': amountPayable,
        'amount_paid': amountPaid,
        'change_amount': changeAmount,
        'sold_at': soldAt.toIso8601String(),
        'outstanding_balance': outstandingBalance,
        'is_credit_sale': isCreditSale ? 1 : 0,
      };

  Sale copyWith({
    int? id,
    String? receiptNumber,
    int? customerId,
    String? customerName,
    double? totalPrice,
    double? amountPayable,
    double? amountPaid,
    double? changeAmount,
    DateTime? soldAt,
    double? outstandingBalance,
    bool? isCreditSale,
  }) => Sale(
        id: id ?? this.id,
        receiptNumber: receiptNumber ?? this.receiptNumber,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        totalPrice: totalPrice ?? this.totalPrice,
        amountPayable: amountPayable ?? this.amountPayable,
        amountPaid: amountPaid ?? this.amountPaid,
        changeAmount: changeAmount ?? this.changeAmount,
        soldAt: soldAt ?? this.soldAt,
        outstandingBalance: outstandingBalance ?? this.outstandingBalance,
        isCreditSale: isCreditSale ?? this.isCreditSale,
      );
}
