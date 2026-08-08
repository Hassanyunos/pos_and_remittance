class LaundryStockItem {
  const LaundryStockItem({
    this.id,
    required this.itemName,
    required this.stockNumber,
    required this.quantityInStock,
    required this.capitalPrice,
    required this.retailPrice,
    required this.minimumAlertQuantity,
    this.picturePath,
    required this.category,
    this.notes,
  });

  final int? id;
  final String itemName;
  final String stockNumber;
  final int quantityInStock;
  final double capitalPrice;
  final double retailPrice;
  final int minimumAlertQuantity;
  final String? picturePath;
  final String category;
  final String? notes;

  factory LaundryStockItem.fromMap(Map<String, Object?> map) =>
      LaundryStockItem(
        id: map['id'] as int?,
        itemName: map['item_name'] as String,
        stockNumber: map['stock_number'] as String,
        quantityInStock: (map['quantity_in_stock'] as num).toInt(),
        capitalPrice: (map['capital_price'] as num).toDouble(),
        retailPrice: (map['retail_price'] as num).toDouble(),
        minimumAlertQuantity: (map['minimum_alert_quantity'] as num).toInt(),
        picturePath: map['picture_path'] as String?,
        category: map['category'] as String,
        notes: map['notes'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'item_name': itemName,
        'stock_number': stockNumber,
        'quantity_in_stock': quantityInStock,
        'capital_price': capitalPrice,
        'retail_price': retailPrice,
        'minimum_alert_quantity': minimumAlertQuantity,
        'picture_path': picturePath,
        'category': category,
        'notes': notes,
      };

  LaundryStockItem copyWith({
    int? id,
    String? itemName,
    String? stockNumber,
    int? quantityInStock,
    double? capitalPrice,
    double? retailPrice,
    int? minimumAlertQuantity,
    String? picturePath,
    String? category,
    String? notes,
  }) =>
      LaundryStockItem(
        id: id ?? this.id,
        itemName: itemName ?? this.itemName,
        stockNumber: stockNumber ?? this.stockNumber,
        quantityInStock: quantityInStock ?? this.quantityInStock,
        capitalPrice: capitalPrice ?? this.capitalPrice,
        retailPrice: retailPrice ?? this.retailPrice,
        minimumAlertQuantity: minimumAlertQuantity ?? this.minimumAlertQuantity,
        picturePath: picturePath ?? this.picturePath,
        category: category ?? this.category,
        notes: notes ?? this.notes,
      );
}
