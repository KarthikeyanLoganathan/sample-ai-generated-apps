import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/basket_vendor.dart';
import '../models/basket_vendor_item.dart';
import '../models/vendor_price_list.dart';
import '../models/vendor.dart';
import '../models/basket_header.dart';
import '../services/database_helper.dart';
import 'basket_vendor_item_detail_screen.dart';

class BasketVendorDetailScreen extends StatefulWidget {
  final BasketVendor basketVendor;

  const BasketVendorDetailScreen({
    super.key,
    required this.basketVendor,
  });

  @override
  State<BasketVendorDetailScreen> createState() =>
      _BasketVendorDetailScreenState();
}

class _BasketVendorDetailScreenState extends State<BasketVendorDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper.instance;

  DateTime _selectedDate = DateTime.now();
  DateTime? _expectedDeliveryDate;

  List<BasketVendorItem> _basketVendorItems = [];
  Vendor? _vendor;
  BasketHeader? _basketHeader;

  BasketVendor? _currentBasketVendor;
  bool _isLoading = true;
  bool _isExistingRecord = false;
  bool _itemsGenerated = false;

  @override
  void initState() {
    super.initState();
    if (widget.basketVendor.date.isNotEmpty) {
      _selectedDate =
          DateTime.tryParse(widget.basketVendor.date) ?? DateTime.now();
    }
    if (widget.basketVendor.expectedDeliveryDate != null) {
      _expectedDeliveryDate =
          DateTime.tryParse(widget.basketVendor.expectedDeliveryDate!);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Auto-persist new basket vendors immediately
    if (widget.basketVendor.uuid.isEmpty) {
      final now = DateTime.now().toIso8601String();
      final uuid = const Uuid().v4();
      final newBasketVendor = BasketVendor(
        uuid: uuid,
        basketUuid: widget.basketVendor.basketUuid,
        vendorUuid: widget.basketVendor.vendorUuid,
        date: _selectedDate.toIso8601String().substring(0, 10),
        expectedDeliveryDate:
            _expectedDeliveryDate?.toIso8601String().substring(0, 10),
        currency: widget.basketVendor.currency,
        updatedAt: now,
      );
      await _dbHelper.insertBasketVendor(newBasketVendor);
      // Reload from database to get the auto-generated data
      final saved = await _dbHelper.getBasketVendor(uuid);
      _currentBasketVendor = saved;
      _isExistingRecord = true;

      // Auto-generate items for new basket vendor
      await _generateItemsInternal();

      // Reload basket vendor to get updated totals after item generation
      final updated = await _dbHelper.getBasketVendor(uuid);
      _currentBasketVendor = updated;
    } else {
      // Check if record exists in database
      final existing =
          await _dbHelper.getBasketVendor(widget.basketVendor.uuid);
      _isExistingRecord = existing != null;
      if (existing != null) {
        _currentBasketVendor = existing;
      }
    }

    // Load vendor
    final vendor = await _dbHelper.getVendor(widget.basketVendor.vendorUuid);

    // Load basket header
    final basketHeader =
        await _dbHelper.getBasketHeader(widget.basketVendor.basketUuid);

    // Load basket vendor items if existing
    List<BasketVendorItem> items = [];
    if (_isExistingRecord) {
      items = await _dbHelper.getBasketVendorItems(_currentBasketVendor!.uuid);
      _itemsGenerated = items.isNotEmpty;
    }

    setState(() {
      _vendor = vendor;
      _basketHeader = basketHeader;
      _basketVendorItems = items;
      _isLoading = false;
    });
  }

  Future<void> _generateItems() async {
    if (_currentBasketVendor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the quotation first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await _generateItemsInternal();

    setState(() {
      _isLoading = false;
      _itemsGenerated = true;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated ${_basketVendorItems.length} items'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _generateItemsInternal() async {
    if (_currentBasketVendor == null) return;

    // Get all basket items
    final basketItems =
        await _dbHelper.getBasketItems(widget.basketVendor.basketUuid);

    // Get all vendor price lists for this vendor
    final vendorPriceLists = await _dbHelper
        .getVendorPriceListsByVendor(widget.basketVendor.vendorUuid);

    // Create a map for quick lookup
    final vplMap = <String, VendorPriceList>{
      for (var vpl in vendorPriceLists) vpl.manufacturerMaterialUuid: vpl,
    };

    // Generate basket vendor items
    for (var basketItem in basketItems) {
      // Check if item already exists
      final existing = _basketVendorItems.where(
        (bvi) => bvi.basketItemUuid == basketItem.uuid,
      );

      if (existing.isNotEmpty) {
        continue; // Skip if already exists
      }

      final vpl = vplMap[basketItem.manufacturerMaterialUuid];

      final item = BasketVendorItem(
        uuid: const Uuid().v4(),
        id: basketItem.id,
        basketVendorUuid: _currentBasketVendor!.uuid,
        basketUuid: widget.basketVendor.basketUuid,
        basketItemUuid: basketItem.uuid,
        vendorPriceListUuid: vpl?.uuid,
        itemAvailableWithVendor: vpl != null,
        manufacturerMaterialUuid: basketItem.manufacturerMaterialUuid,
        materialUuid: basketItem.materialUuid,
        model: basketItem.model,
        quantity: basketItem.quantity,
        maxRetailPrice: basketItem.maxRetailPrice,
        rate: vpl?.rate ?? 0.0,
        rateBeforeTax: vpl?.rateBeforeTax ?? 0.0,
        basePrice: vpl != null ? vpl.rateBeforeTax * basketItem.quantity : 0.0,
        taxPercent: vpl?.taxPercent ?? 0.0,
        taxAmount: vpl != null
            ? (vpl.rateBeforeTax * basketItem.quantity * vpl.taxPercent / 100.0)
            : 0.0,
        totalAmount: vpl != null ? vpl.rate * basketItem.quantity : 0.0,
        currency: widget.basketVendor.currency,
        updatedAt: DateTime.now().toIso8601String(),
      );

      await _dbHelper.insertBasketVendorItem(item);
      _basketVendorItems.add(item);
    }

    _itemsGenerated = true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          Navigator.of(context).pop(_currentBasketVendor);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(_currentBasketVendor);
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_basket, size: 20),
              const SizedBox(width: 8),
              Text(
                _basketHeader?.id != null ? '${_basketHeader!.id}' : '...',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 8),
              const Text('|', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                _currentBasketVendor?.id != null
                    ? 'Quotation #${_currentBasketVendor!.id}'
                    : 'Quotation',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vendor Info
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _vendor?.name ?? 'Unknown Vendor',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (_vendor?.description != null) ...[
                                const SizedBox(height: 4),
                                Text(_vendor!.description!),
                              ],
                              if (_vendor?.address != null) ...[
                                const SizedBox(height: 2),
                                Text('Address: ${_vendor!.address}'),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Date fields in one row
                      Row(
                        children: [
                          // Quotation Date
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) {
                                  setState(() {
                                    _selectedDate = date;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Quotation Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  DateFormat('dd-MMM-yyyy')
                                      .format(_selectedDate),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Expected Delivery Date
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _expectedDeliveryDate ??
                                      DateTime.now()
                                          .add(const Duration(days: 7)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2100),
                                );
                                if (date != null) {
                                  setState(() {
                                    _expectedDeliveryDate = date;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Expected Delivery Date',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_expectedDeliveryDate != null)
                                        IconButton(
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: () {
                                            setState(() {
                                              _expectedDeliveryDate = null;
                                            });
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.calendar_today),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  _expectedDeliveryDate != null
                                      ? DateFormat('dd-MMM-yyyy')
                                          .format(_expectedDeliveryDate!)
                                      : 'Not set',
                                  style: TextStyle(
                                    color: _expectedDeliveryDate != null
                                        ? null
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Summary
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildSummaryRow(
                                'Available Items:',
                                '${_currentBasketVendor?.numberOfAvailableItems ?? 0}',
                                Colors.green.shade700,
                              ),
                              if ((_currentBasketVendor
                                          ?.numberOfUnavailableItems ??
                                      0) >
                                  0)
                                _buildSummaryRow(
                                  'Unavailable Items:',
                                  '${_currentBasketVendor?.numberOfUnavailableItems ?? 0}',
                                  Colors.red,
                                ),
                              const Divider(),
                              _buildSummaryRow(
                                'Base Price:',
                                '${widget.basketVendor.currency} ${(_currentBasketVendor?.basePrice ?? 0.0).toStringAsFixed(2)}',
                              ),
                              _buildSummaryRow(
                                'Tax Amount:',
                                '${widget.basketVendor.currency} ${(_currentBasketVendor?.taxAmount ?? 0.0).toStringAsFixed(2)}',
                              ),
                              const Divider(),
                              _buildSummaryRow(
                                'Total Amount:',
                                '${widget.basketVendor.currency} ${(_currentBasketVendor?.totalAmount ?? 0.0).toStringAsFixed(2)}',
                                Colors.blue.shade900,
                                true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Items section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Items',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (!_itemsGenerated)
                            ElevatedButton.icon(
                              onPressed: _currentBasketVendor == null
                                  ? null
                                  : _generateItems,
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Generate Items'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (_basketVendorItems.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                const Icon(Icons.inventory_2,
                                    size: 64, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  _currentBasketVendor == null
                                      ? 'Save quotation first, then generate items'
                                      : 'Click "Generate Items" to populate from basket',
                                  style: const TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._basketVendorItems.map(
                          (item) => _buildVendorItemCard(item),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      [Color? valueColor, bool isBold = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
              fontSize: isBold ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorItemCard(BasketVendorItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: item.itemAvailableWithVendor ? null : Colors.red.shade50,
      child: ListTile(
        leading: Icon(
          item.itemAvailableWithVendor ? Icons.check_circle : Icons.cancel,
          color:
              item.itemAvailableWithVendor ? Colors.green.shade700 : Colors.red,
        ),
        title: Text(
          item.model ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qty: ${item.quantity.toStringAsFixed(2)} • Rate: ${item.currency} ${item.rate.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 2),
            if (item.itemAvailableWithVendor)
              Text(
                'Total: ${item.currency} ${item.totalAmount.toStringAsFixed(2)} (Tax: ${item.taxPercent.toStringAsFixed(1)}%)',
                style: const TextStyle(fontWeight: FontWeight.w500),
              )
            else
              const Text(
                'Not available with this vendor',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  BasketVendorItemDetailScreen(basketVendorItem: item),
            ),
          );
          if (result != null) {
            _loadData();
          }
        },
      ),
    );
  }
}
