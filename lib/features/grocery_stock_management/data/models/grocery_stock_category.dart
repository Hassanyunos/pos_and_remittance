class GroceryStockCategory {
  const GroceryStockCategory({
    this.id,
    required this.name,
  });

  final int? id;
  final String name;

  factory GroceryStockCategory.fromMap(Map<String, Object?> map) => GroceryStockCategory(
        id: map['id'] as int?,
        name: map['name'] as String,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
      };

  GroceryStockCategory copyWith({int? id, String? name}) => GroceryStockCategory(
        id: id ?? this.id,
        name: name ?? this.name,
      );
}
