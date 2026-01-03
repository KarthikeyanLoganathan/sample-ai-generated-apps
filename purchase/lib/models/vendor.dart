// Helper function to safely parse int? values from maps
int? _toIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}

class Vendor {
  final String uuid;
  final int? id;
  final String name;
  final String? description;
  final String? address;
  final String? geoLocation;
  final DateTime updatedAt;

  Vendor({
    required this.uuid,
    this.id,
    required this.name,
    this.description,
    this.address,
    this.geoLocation,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id': id,
      'name': name,
      'description': description,
      'address': address,
      'geo_location': geoLocation,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      uuid: map['uuid'] as String,
      id: _toIntNullable(map['id']),
      name: map['name'] as String,
      description: map['description'] as String?,
      address: map['address'] as String?,
      geoLocation: map['geo_location'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Vendor copyWith({
    String? uuid,
    int? id,
    String? name,
    String? description,
    String? address,
    String? geoLocation,
    DateTime? updatedAt,
  }) {
    return Vendor(
      uuid: uuid ?? this.uuid,
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      geoLocation: geoLocation ?? this.geoLocation,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vendor && other.uuid == uuid;
  }

  @override
  int get hashCode => uuid.hashCode;
}
