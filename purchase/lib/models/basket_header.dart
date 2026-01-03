class BasketHeader {
  final String uuid;
  final int? id;
  final String date;
  final String? description;
  final String? expectedDeliveryDate;
  final double totalPrice;
  final String currency;
  final int numberOfItems;
  final String updatedAt;

  BasketHeader({
    required this.uuid,
    this.id,
    required this.date,
    this.description,
    this.expectedDeliveryDate,
    this.totalPrice = 0.0,
    this.currency = 'INR',
    this.numberOfItems = 0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id': id,
      'date': date,
      'description': description,
      'expected_delivery_date': expectedDeliveryDate,
      'total_price': totalPrice,
      'currency': currency,
      'number_of_items': numberOfItems,
      'updated_at': updatedAt,
    };
  }

  factory BasketHeader.fromMap(Map<String, dynamic> map) {
    return BasketHeader(
      uuid: map['uuid'],
      id: map['id'],
      date: map['date'],
      description: map['description'],
      expectedDeliveryDate: map['expected_delivery_date'],
      totalPrice: map['total_price'] ?? 0.0,
      currency: map['currency'] ?? 'INR',
      numberOfItems: map['number_of_items'] ?? 0,
      updatedAt: map['updated_at'],
    );
  }

  BasketHeader copyWith({
    String? uuid,
    int? id,
    String? date,
    String? description,
    String? expectedDeliveryDate,
    double? totalPrice,
    String? currency,
    int? numberOfItems,
    String? updatedAt,
  }) {
    return BasketHeader(
      uuid: uuid ?? this.uuid,
      id: id ?? this.id,
      date: date ?? this.date,
      description: description ?? this.description,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      totalPrice: totalPrice ?? this.totalPrice,
      currency: currency ?? this.currency,
      numberOfItems: numberOfItems ?? this.numberOfItems,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
