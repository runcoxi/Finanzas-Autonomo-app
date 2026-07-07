class Client {
  final int? id;
  final String name;
  final String nif;
  final String address;
  final String notes;

  const Client({
    this.id,
    required this.name,
    this.nif = '',
    this.address = '',
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'nif': nif,
        'address': address,
        'notes': notes,
      };

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as int?,
        name: map['name'] as String,
        nif: map['nif'] as String? ?? '',
        address: map['address'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
      );
}
