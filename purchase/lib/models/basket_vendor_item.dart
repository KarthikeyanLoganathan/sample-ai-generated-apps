class BasketVendorItem {
  final String uuid;
  final int? id;
  final String basketVendorUuid;
  final String basketUuid;
  final String basketItemUuid;
  final String? vendorPriceListUuid;
  final bool itemAvailableWithVendor;
  final String? manufacturerMaterialUuid;
  final String? materialUuid;
  final String? model;
  final double quantity;
  final double? maxRetailPrice;
  final double rate;
  final double rateBeforeTax;
  final double basePrice;
  final double taxPercent;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final String updatedAt;

  BasketVendorItem({
    required this.uuid,
    this.id,
    required this.basketVendorUuid,
    required this.basketUuid,
    required this.basketItemUuid,
    this.vendorPriceListUuid,
    this.itemAvailableWithVendor = false,
    this.manufacturerMaterialUuid,
    this.materialUuid,
    this.model,
    this.quantity = 1.0,
    this.maxRetailPrice,
    this.rate = 0.0,
    this.rateBeforeTax = 0.0,
    this.basePrice = 0.0,
    this.taxPercent = 0.0,
    this.taxAmount = 0.0,
    this.totalAmount = 0.0,
    this.currency = 'INR',
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'id': id,
      'basket_vendor_uuid': basketVendorUuid,
      'basket_uuid': basketUuid,
      'basket_item_uuid': basketItemUuid,
      'vendor_price_list_uuid': vendorPriceListUuid,
      'item_available_with_vendor': itemAvailableWithVendor ? 1 : 0,
      'manufacturer_material_uuid': manufacturerMaterialUuid,
      'material_uuid': materialUuid,
      'model': model,
      'quantity': quantity,
      'max_retail_price': maxRetailPrice,
      'rate': rate,
      'rate_before_tax': rateBeforeTax,
      'base_price': basePrice,
      'tax_percent': taxPercent,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'updated_at': updatedAt,
    };
  }

  factory BasketVendorItem.fromMap(Map<String, dynamic> map) {
    return BasketVendorItem(
      uuid: map['uuid'],
      id: map['id'],
      basketVendorUuid: map['basket_vendor_uuid'],
      basketUuid: map['basket_uuid'],
      basketItemUuid: map['basket_item_uuid'],
      vendorPriceListUuid: map['vendor_price_list_uuid'],
      itemAvailableWithVendor: (map['item_available_with_vendor'] ?? 0) == 1,
      manufacturerMaterialUuid: map['manufacturer_material_uuid'],
      materialUuid: map['material_uuid'],
      model: map['model'],
      quantity: map['quantity'] ?? 1.0,
      maxRetailPrice: map['max_retail_price'],
      rate: map['rate'] ?? 0.0,
      rateBeforeTax: map['rate_before_tax'] ?? 0.0,
      basePrice: map['base_price'] ?? 0.0,
      taxPercent: map['tax_percent'] ?? 0.0,
      taxAmount: map['tax_amount'] ?? 0.0,
      totalAmount: map['total_amount'] ?? 0.0,
      currency: map['currency'] ?? 'INR',
      updatedAt: map['updated_at'],
    );
  }

  BasketVendorItem copyWith({
    String? uuid,
    int? id,
    String? basketVendorUuid,
    String? basketUuid,
    String? basketItemUuid,
    String? vendorPriceListUuid,
    bool? itemAvailableWithVendor,
    String? manufacturerMaterialUuid,
    String? materialUuid,
    String? model,
    double? quantity,
    double? maxRetailPrice,
    double? rate,
    double? rateBeforeTax,
    double? basePrice,
    double? taxPercent,
    double? taxAmount,
    double? totalAmount,
    String? currency,
    String? updatedAt,
  }) {
    return BasketVendorItem(
      uuid: uuid ?? this.uuid,
      id: id ?? this.id,
      basketVendorUuid: basketVendorUuid ?? this.basketVendorUuid,
      basketUuid: basketUuid ?? this.basketUuid,
      basketItemUuid: basketItemUuid ?? this.basketItemUuid,
      vendorPriceListUuid: vendorPriceListUuid ?? this.vendorPriceListUuid,
      itemAvailableWithVendor:
          itemAvailableWithVendor ?? this.itemAvailableWithVendor,
      manufacturerMaterialUuid:
          manufacturerMaterialUuid ?? this.manufacturerMaterialUuid,
      materialUuid: materialUuid ?? this.materialUuid,
      model: model ?? this.model,
      quantity: quantity ?? this.quantity,
      maxRetailPrice: maxRetailPrice ?? this.maxRetailPrice,
      rate: rate ?? this.rate,
      rateBeforeTax: rateBeforeTax ?? this.rateBeforeTax,
      basePrice: basePrice ?? this.basePrice,
      taxPercent: taxPercent ?? this.taxPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
