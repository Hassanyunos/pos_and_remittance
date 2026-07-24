enum RemittanceType { cashIn, cashOut }
enum RemittanceStatus { pending, receivedByCustomer }

class Remittance {
  const Remittance({
    this.id,
    required this.fundId,
    required this.remittanceType,
    required this.referenceNumber,
    required this.amount,
    required this.charge,
    this.processedAt,
    this.customerId,
    this.customerName,
    this.customerIdPicturePath,
    this.processedBy,
    this.editedBy,
    required this.remittanceStatus,
    this.notes,
  });

  final int? id;
  final int fundId;
  final RemittanceType remittanceType;
  final String referenceNumber;
  final double amount;
  final double charge;
  final DateTime? processedAt;
  final int? customerId;
  final String? customerName;
  final String? customerIdPicturePath;
  final String? processedBy;
  final String? editedBy;
  final RemittanceStatus remittanceStatus;
  final String? notes;

  factory Remittance.fromMap(Map<String, Object?> map) => Remittance(
        id: map['id'] as int?,
        fundId: map['fund_id'] as int,
        remittanceType: (map['remittance_type'] as String?) == RemittanceType.cashOut.name
            ? RemittanceType.cashOut
            : RemittanceType.cashIn,
        referenceNumber: map['reference_number'] as String,
        amount: (map['amount'] as num).toDouble(),
        charge: (map['charge'] as num).toDouble(),
        processedAt: map['processed_at'] == null ? null : DateTime.tryParse(map['processed_at'] as String),
        customerId: map['customer_id'] as int?,
        customerName: map['customer_name'] as String?,
        customerIdPicturePath: map['customer_id_picture_path'] as String?,
        processedBy: map['processed_by'] as String?,
        editedBy: map['edited_by'] as String?,
        remittanceStatus: (map['remittance_status'] as String?) == RemittanceStatus.receivedByCustomer.name
            ? RemittanceStatus.receivedByCustomer
            : RemittanceStatus.pending,
        notes: map['notes'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'fund_id': fundId,
        'remittance_type': remittanceType.name,
        'reference_number': referenceNumber,
        'amount': amount,
        'charge': charge,
        'processed_at': processedAt?.toIso8601String(),
        'customer_id': customerId,
        'customer_name': customerName,
        'customer_id_picture_path': customerIdPicturePath,
        'processed_by': processedBy,
        'edited_by': editedBy,
        'remittance_status': remittanceStatus.name,
        'notes': notes,
      };

  Remittance copyWith({
    int? id,
    int? fundId,
    RemittanceType? remittanceType,
    String? referenceNumber,
    double? amount,
    double? charge,
    DateTime? processedAt,
    int? customerId,
    String? customerName,
    String? customerIdPicturePath,
    String? processedBy,
    String? editedBy,
    RemittanceStatus? remittanceStatus,
    String? notes,
  }) => Remittance(
        id: id ?? this.id,
        fundId: fundId ?? this.fundId,
        remittanceType: remittanceType ?? this.remittanceType,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        amount: amount ?? this.amount,
        charge: charge ?? this.charge,
        processedAt: processedAt ?? this.processedAt,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        customerIdPicturePath: customerIdPicturePath ?? this.customerIdPicturePath,
        processedBy: processedBy ?? this.processedBy,
        editedBy: editedBy ?? this.editedBy,
        remittanceStatus: remittanceStatus ?? this.remittanceStatus,
        notes: notes ?? this.notes,
      );
}
