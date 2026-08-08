class LaundryServiceItem {
  const LaundryServiceItem({
    this.id,
    required this.name,
    required this.price,
    this.addOnItemIds,
    this.notes,
  });

  final int? id;
  final String name;
  final double price;
  final String? addOnItemIds;
  final String? notes;

  factory LaundryServiceItem.fromMap(Map<String, Object?> map) =>
      LaundryServiceItem(
        id: map['id'] as int?,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        addOnItemIds: map['add_on_item_ids'] as String?,
        notes: map['notes'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'add_on_item_ids': addOnItemIds,
        'notes': notes,
      };

  LaundryServiceItem copyWith({
    int? id,
    String? name,
    double? price,
    String? addOnItemIds,
    String? notes,
  }) =>
      LaundryServiceItem(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        addOnItemIds: addOnItemIds ?? this.addOnItemIds,
        notes: notes ?? this.notes,
      );
}
