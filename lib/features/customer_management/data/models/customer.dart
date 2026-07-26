class Customer {
  const Customer({
    this.id,
    required this.name,
    this.address,
    this.contactNumber,
    this.idPicturePath,
    this.status = CustomerStatus.standard,
    this.currentBalance = 0,
  });

  final int? id;
  final String name;
  final String? address;
  final String? contactNumber;
  final String? idPicturePath;
  final CustomerStatus status;
  final double currentBalance;

  factory Customer.fromMap(Map<String, Object?> map) => Customer(
        id: map['id'] as int?,
        name: map['name'] as String,
        address: map['address'] as String?,
        contactNumber: map['contact_number'] as String?,
        idPicturePath: map['id_picture_path'] as String?,
        status: CustomerStatusX.fromValue(map['status'] as String?),
        currentBalance: (map['current_balance'] as num?)?.toDouble() ?? 0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'contact_number': contactNumber,
        'id_picture_path': idPicturePath,
        'status': status.value,
        'current_balance': currentBalance,
      };

  Customer copyWith({
    int? id,
    String? name,
    String? address,
    String? contactNumber,
    String? idPicturePath,
    CustomerStatus? status,
    double? currentBalance,
  }) => Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        contactNumber: contactNumber ?? this.contactNumber,
        idPicturePath: idPicturePath ?? this.idPicturePath,
        status: status ?? this.status,
        currentBalance: currentBalance ?? this.currentBalance,
      );
}

enum CustomerStatus { standard, allowedToBorrow }

extension CustomerStatusX on CustomerStatus {
  String get value {
    switch (this) {
      case CustomerStatus.standard:
        return 'standard';
      case CustomerStatus.allowedToBorrow:
        return 'allowed_to_borrow';
    }
  }

  static CustomerStatus fromValue(String? value) {
    switch (value) {
      case 'allowed_to_borrow':
        return CustomerStatus.allowedToBorrow;
      case 'standard':
      default:
        return CustomerStatus.standard;
    }
  }
}
