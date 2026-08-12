class LaundryServiceItem {
  const LaundryServiceItem({
    this.id,
    required this.name,
    required this.price,
    required this.maxWeightKg,
    this.addOnItemIds,
    this.notes,
  });

  final int? id;
  final String name;
  final double price;
  final double maxWeightKg;
  final String? addOnItemIds;
  final String? notes;

  factory LaundryServiceItem.fromMap(Map<String, Object?> map) =>
      LaundryServiceItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        maxWeightKg: (map['max_weight_kg'] as num?)?.toDouble() ?? 1,
        addOnItemIds: map['add_on_item_ids'] as String?,
        notes: map['notes'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'max_weight_kg': maxWeightKg,
        'add_on_item_ids': addOnItemIds,
        'notes': notes,
      };

  LaundryServiceItem copyWith({
    int? id,
    String? name,
    double? price,
    double? maxWeightKg,
    String? addOnItemIds,
    String? notes,
  }) =>
      LaundryServiceItem(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        maxWeightKg: maxWeightKg ?? this.maxWeightKg,
        addOnItemIds: addOnItemIds ?? this.addOnItemIds,
        notes: notes ?? this.notes,
      );
}
