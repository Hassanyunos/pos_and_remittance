enum FundType { cash, eCash }

class Fund {
  const Fund({
    this.id,
    required this.name,
    required this.currentBalance,
    required this.fundType,
  });

  final int? id;
  final String name;
  final double currentBalance;
  final FundType fundType;

  factory Fund.fromMap(Map<String, Object?> map) => Fund(
        id: map['id'] as int?,
        name: map['name'] as String,
        currentBalance: (map['current_balance'] as num).toDouble(),
        fundType: (map['fund_type'] as String) == FundType.eCash.name
            ? FundType.eCash
            : FundType.cash,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'current_balance': currentBalance,
        'fund_type': fundType.name,
      };

  Fund copyWith({int? id, String? name, double? currentBalance, FundType? fundType}) => Fund(
        id: id ?? this.id,
        name: name ?? this.name,
        currentBalance: currentBalance ?? this.currentBalance,
        fundType: fundType ?? this.fundType,
      );
}
