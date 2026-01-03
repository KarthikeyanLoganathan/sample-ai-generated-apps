// Helper function to safely parse int? values from maps
int? _toIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}

class Manufacturer {
  final String uuid;
  final int? id;
  final String name;
  final String? description;
  final DateTime updatedAt;

  Manufacturer({
    required this.uuid,
    this.id,
    required this.name,
    this.description,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id': id,
      'name': name,
      'description': description,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory Manufacturer.fromMap(Map<String, dynamic> map) {
    return Manufacturer(
      uuid: map['uuid'] as String,
      id: _toIntNullable(map['id']),
      name: map['name'] as String,
      description: map['description'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Manufacturer copyWith({
    String? uuid,
    int? id,
    String? name,
    String? description,
    DateTime? updatedAt,
  }) {
    return Manufacturer(
      uuid: uuid ?? this.uuid,
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Manufacturer && other.uuid == uuid;
  }

  @override
  int get hashCode => uuid.hashCode;
}
