class SaleItem {
  const SaleItem({
    this.id,
    required this.saleId,
    required this.itemName,
    required this.itemBarcode,
    required this.quantityBought,
    required this.retailPrice,
  });

  final int? id;
  final int saleId;
  final String itemName;
  final String itemBarcode;
  final int quantityBought;
  final double retailPrice;

  factory SaleItem.fromMap(Map<String, Object?> map) => SaleItem(
        id: map['id'] as int?,
        saleId: map['sale_id'] as int,
        itemName: map['item_name'] as String,
        itemBarcode: map['item_barcode'] as String,
        quantityBought: (map['quantity_bought'] as num).toInt(),
        retailPrice: (map['retail_price'] as num).toDouble(),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'sale_id': saleId,
        'item_name': itemName,
        'item_barcode': itemBarcode,
        'quantity_bought': quantityBought,
        'retail_price': retailPrice,
      };

  SaleItem copyWith({
    int? id,
    int? saleId,
    String? itemName,
    String? itemBarcode,
    int? quantityBought,
    double? retailPrice,
  }) => SaleItem(
        id: id ?? this.id,
        saleId: saleId ?? this.saleId,
        itemName: itemName ?? this.itemName,
        itemBarcode: itemBarcode ?? this.itemBarcode,
        quantityBought: quantityBought ?? this.quantityBought,
        retailPrice: retailPrice ?? this.retailPrice,
      );
}
