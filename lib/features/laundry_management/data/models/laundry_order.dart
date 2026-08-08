enum LaundryOrderStatus {
  pending,
  inProgress,
  readyForPickup,
  pickedUp,
}

class LaundryOrder {
  const LaundryOrder({
    this.id,
    required this.referenceNumber,
    this.customerId,
    required this.isWalkIn,
    required this.customerName,
    this.customerContact,
    required this.weightKg,
    required this.clothesCount,
    required this.laundryBaseAmount,
    this.serviceId,
    this.serviceName,
    this.serviceAddOns,
    this.serviceAddOnItemIds,
    this.addOns,
    this.addOnItemIds,
    this.paidAddOns,
    this.paidAddOnItemIds,
    required this.addOnTotal,
    required this.amountPayable,
    required this.amountPaid,
    required this.changeAmount,
    required this.status,
    this.itemImagePath,
    this.pickupProofImagePath,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String referenceNumber;
  final int? customerId;
  final bool isWalkIn;
  final String customerName;
  final String? customerContact;
  final double weightKg;
  final int clothesCount;
  final double laundryBaseAmount;
  final int? serviceId;
  final String? serviceName;
  final String? serviceAddOns;
  final String? serviceAddOnItemIds;
  final String? addOns;
  final String? addOnItemIds;
  final String? paidAddOns;
  final String? paidAddOnItemIds;
  final double addOnTotal;
  final double amountPayable;
  final double amountPaid;
  final double changeAmount;
  final LaundryOrderStatus status;
  final String? itemImagePath;
  final String? pickupProofImagePath;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get netReceived => amountPaid - changeAmount;

  factory LaundryOrder.fromMap(Map<String, Object?> map) => LaundryOrder(
        id: map['id'] as int?,
        referenceNumber: map['reference_number'] as String,
        customerId: map['customer_id'] as int?,
        isWalkIn: (map['is_walk_in'] as int?) != 0,
        customerName: map['customer_name'] as String,
        customerContact: map['customer_contact'] as String?,
        weightKg: (map['weight_kg'] as num).toDouble(),
        clothesCount: (map['clothes_count'] as num).toInt(),
        laundryBaseAmount: (map['laundry_base_amount'] as num?)?.toDouble() ??
            (map['amount_payable'] as num).toDouble(),
        serviceId: map['service_id'] as int?,
        serviceName: map['service_name'] as String?,
        serviceAddOns: map['service_add_ons'] as String?,
        serviceAddOnItemIds: map['service_add_on_item_ids'] as String?,
        addOns: map['add_ons'] as String?,
        addOnItemIds: map['add_on_item_ids'] as String?,
        paidAddOns:
            (map['paid_add_ons'] as String?) ?? (map['add_ons'] as String?),
        paidAddOnItemIds: (map['paid_add_on_item_ids'] as String?) ??
            (map['add_on_item_ids'] as String?),
        addOnTotal: (map['add_on_total'] as num?)?.toDouble() ?? 0,
        amountPayable: (map['amount_payable'] as num).toDouble(),
        amountPaid: (map['amount_paid'] as num).toDouble(),
        changeAmount: (map['change_amount'] as num).toDouble(),
        status: switch (map['status'] as String?) {
          'inProgress' => LaundryOrderStatus.inProgress,
          'readyForPickup' => LaundryOrderStatus.readyForPickup,
          'pickedUp' => LaundryOrderStatus.pickedUp,
          _ => LaundryOrderStatus.pending,
        },
        itemImagePath: map['item_image_path'] as String?,
        pickupProofImagePath: map['pickup_proof_image_path'] as String?,
        notes: map['notes'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'reference_number': referenceNumber,
        'customer_id': customerId,
        'is_walk_in': isWalkIn ? 1 : 0,
        'customer_name': customerName,
        'customer_contact': customerContact,
        'weight_kg': weightKg,
        'clothes_count': clothesCount,
        'laundry_base_amount': laundryBaseAmount,
        'service_id': serviceId,
        'service_name': serviceName,
        'service_add_ons': serviceAddOns,
        'service_add_on_item_ids': serviceAddOnItemIds,
        'add_ons': addOns,
        'add_on_item_ids': addOnItemIds,
        'paid_add_ons': paidAddOns,
        'paid_add_on_item_ids': paidAddOnItemIds,
        'add_on_total': addOnTotal,
        'amount_payable': amountPayable,
        'amount_paid': amountPaid,
        'change_amount': changeAmount,
        'status': status.name,
        'item_image_path': itemImagePath,
        'pickup_proof_image_path': pickupProofImagePath,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  LaundryOrder copyWith({
    int? id,
    String? referenceNumber,
    int? customerId,
    bool? isWalkIn,
    String? customerName,
    String? customerContact,
    double? weightKg,
    int? clothesCount,
    double? laundryBaseAmount,
    int? serviceId,
    String? serviceName,
    String? serviceAddOns,
    String? serviceAddOnItemIds,
    String? addOns,
    String? addOnItemIds,
    String? paidAddOns,
    String? paidAddOnItemIds,
    double? addOnTotal,
    double? amountPayable,
    double? amountPaid,
    double? changeAmount,
    LaundryOrderStatus? status,
    String? itemImagePath,
    String? pickupProofImagePath,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      LaundryOrder(
        id: id ?? this.id,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        customerId: customerId ?? this.customerId,
        isWalkIn: isWalkIn ?? this.isWalkIn,
        customerName: customerName ?? this.customerName,
        customerContact: customerContact ?? this.customerContact,
        weightKg: weightKg ?? this.weightKg,
        clothesCount: clothesCount ?? this.clothesCount,
        laundryBaseAmount: laundryBaseAmount ?? this.laundryBaseAmount,
        serviceId: serviceId ?? this.serviceId,
        serviceName: serviceName ?? this.serviceName,
        serviceAddOns: serviceAddOns ?? this.serviceAddOns,
        serviceAddOnItemIds: serviceAddOnItemIds ?? this.serviceAddOnItemIds,
        addOns: addOns ?? this.addOns,
        addOnItemIds: addOnItemIds ?? this.addOnItemIds,
        paidAddOns: paidAddOns ?? this.paidAddOns,
        paidAddOnItemIds: paidAddOnItemIds ?? this.paidAddOnItemIds,
        addOnTotal: addOnTotal ?? this.addOnTotal,
        amountPayable: amountPayable ?? this.amountPayable,
        amountPaid: amountPaid ?? this.amountPaid,
        changeAmount: changeAmount ?? this.changeAmount,
        status: status ?? this.status,
        itemImagePath: itemImagePath ?? this.itemImagePath,
        pickupProofImagePath: pickupProofImagePath ?? this.pickupProofImagePath,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
