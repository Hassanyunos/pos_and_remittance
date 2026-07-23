class Customer {
  const Customer({
    this.id,
    required this.name,
    this.address,
    this.contactNumber,
    this.idPicturePath,
  });

  final int? id;
  final String name;
  final String? address;
  final String? contactNumber;
  final String? idPicturePath;

  factory Customer.fromMap(Map<String, Object?> map) => Customer(
        id: map['id'] as int?,
        name: map['name'] as String,
        address: map['address'] as String?,
        contactNumber: map['contact_number'] as String?,
        idPicturePath: map['id_picture_path'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'contact_number': contactNumber,
        'id_picture_path': idPicturePath,
      };

  Customer copyWith({
    int? id,
    String? name,
    String? address,
    String? contactNumber,
    String? idPicturePath,
  }) => Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        address: address ?? this.address,
        contactNumber: contactNumber ?? this.contactNumber,
        idPicturePath: idPicturePath ?? this.idPicturePath,
      );
}
