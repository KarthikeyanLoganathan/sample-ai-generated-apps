class BasketVendor {
  final String uuid;
  final int? id;
  final String basketUuid;
  final String vendorUuid;
  final String date;
  final String? expectedDeliveryDate;
  final double basePrice;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final int numberOfAvailableItems;
  final int numberOfUnavailableItems;
  final String updatedAt;

  BasketVendor({
    required this.uuid,
    this.id,
    required this.basketUuid,
    required this.vendorUuid,
    required this.date,
    this.expectedDeliveryDate,
    this.basePrice = 0.0,
    this.taxAmount = 0.0,
    this.totalAmount = 0.0,
    this.currency = 'INR',
    this.numberOfAvailableItems = 0,
    this.numberOfUnavailableItems = 0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id': id,
      'basket_uuid': basketUuid,
      'vendor_uuid': vendorUuid,
      'date': date,
      'expected_delivery_date': expectedDeliveryDate,
      'base_price': basePrice,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'number_of_available_items': numberOfAvailableItems,
      'number_of_unavailable_items': numberOfUnavailableItems,
      'updated_at': updatedAt,
    };
  }

  factory BasketVendor.fromMap(Map<String, dynamic> map) {
    return BasketVendor(
      uuid: map['uuid'],
      id: map['id'],
      basketUuid: map['basket_uuid'],
      vendorUuid: map['vendor_uuid'],
      date: map['date'],
      expectedDeliveryDate: map['expected_delivery_date'],
      basePrice: map['base_price'] ?? 0.0,
      taxAmount: map['tax_amount'] ?? 0.0,
      totalAmount: map['total_amount'] ?? 0.0,
      currency: map['currency'] ?? 'INR',
      numberOfAvailableItems: map['number_of_available_items'] ?? 0,
      numberOfUnavailableItems: map['number_of_unavailable_items'] ?? 0,
      updatedAt: map['updated_at'],
    );
  }

  BasketVendor copyWith({
    String? uuid,
    int? id,
    String? basketUuid,
    String? vendorUuid,
    String? date,
    String? expectedDeliveryDate,
    double? basePrice,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    int? numberOfAvailableItems,
    int? numberOfUnavailableItems,
    String? updatedAt,
  }) {
    return BasketVendor(
      uuid: uuid ?? this.uuid,
      id: id ?? this.id,
      basketUuid: basketUuid ?? this.basketUuid,
      vendorUuid: vendorUuid ?? this.vendorUuid,
      date: date ?? this.date,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      basePrice: basePrice ?? this.basePrice,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      numberOfAvailableItems:
          numberOfAvailableItems ?? this.numberOfAvailableItems,
      numberOfUnavailableItems:
          numberOfUnavailableItems ?? this.numberOfUnavailableItems,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
