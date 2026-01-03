// Helper function to safely parse numeric values from maps
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int? _toIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  return null;
}

class PurchaseOrder {
  final String uuid;
  final int? id;
  final String vendorUuid;
  final DateTime date;
  final double basePrice;
  final double taxAmount;
  final double totalAmount;
  final String? currency;
  final DateTime orderDate;
  final DateTime? expectedDeliveryDate;
  final double amountPaid;
  final double amountBalance;
  final bool completed;
  final DateTime updatedAt;

  PurchaseOrder({
    required this.uuid,
    this.id,
    required this.vendorUuid,
    required this.date,
    required this.basePrice,
    required this.taxAmount,
    required this.totalAmount,
    this.currency,
    required this.orderDate,
    this.expectedDeliveryDate,
    this.amountPaid = 0.0,
    this.amountBalance = 0.0,
    this.completed = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'uuid': uuid,
      'vendor_uuid': vendorUuid,
      'date': date.toIso8601String(),
      'base_price': basePrice,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'order_date': orderDate.toIso8601String(),
      'expected_delivery_date': expectedDeliveryDate?.toIso8601String(),
      'amount_paid': amountPaid,
      'amount_balance': amountBalance,
      'completed': completed ? 1 : 0,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    return PurchaseOrder(
      uuid: map['uuid'] as String,
      id: _toIntNullable(map['id']),
      vendorUuid: map['vendor_uuid'] as String,
      date: map['date'] != null && (map['date'] as String).isNotEmpty
          ? DateTime.parse(map['date'] as String)
          : DateTime.now(),
      basePrice: _toDouble(map['base_price']),
      taxAmount: _toDouble(map['tax_amount']),
      totalAmount: _toDouble(map['total_amount']),
      currency: map['currency'] as String?,
      orderDate:
          map['order_date'] != null && (map['order_date'] as String).isNotEmpty
              ? DateTime.parse(map['order_date'] as String)
              : DateTime.now(),
      expectedDeliveryDate: map['expected_delivery_date'] != null &&
              (map['expected_delivery_date'] as String).isNotEmpty
          ? DateTime.parse(map['expected_delivery_date'] as String)
          : null,
      amountPaid: _toDouble(map['amount_paid']),
      amountBalance: _toDouble(map['amount_balance']),
      completed: (map['completed'] == 1 || map['completed'] == true),
      updatedAt:
          map['updated_at'] != null && (map['updated_at'] as String).isNotEmpty
              ? DateTime.parse(map['updated_at'] as String)
              : DateTime.now().toUtc(),
    );
  }

  PurchaseOrder copyWith({
    String? uuid,
    int? id,
    String? vendorUuid,
    DateTime? date,
    double? basePrice,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    DateTime? orderDate,
    DateTime? expectedDeliveryDate,
    double? amountPaid,
    double? amountBalance,
    bool? completed,
    DateTime? updatedAt,
  }) {
    return PurchaseOrder(
      uuid: uuid ?? this.uuid,
      id: id ?? this.id,
      vendorUuid: vendorUuid ?? this.vendorUuid,
      date: date ?? this.date,
      basePrice: basePrice ?? this.basePrice,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      orderDate: orderDate ?? this.orderDate,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      amountPaid: amountPaid ?? this.amountPaid,
      amountBalance: amountBalance ?? this.amountBalance,
      completed: completed ?? this.completed,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
