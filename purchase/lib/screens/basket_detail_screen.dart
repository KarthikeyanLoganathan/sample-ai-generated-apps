import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/basket_header.dart';
import '../models/basket_item.dart';
import '../models/manufacturer_material.dart';
import '../models/manufacturer.dart';
import '../models/material.dart' as models;
import '../services/database_helper.dart';
import 'basket_item_detail_screen.dart';
import 'basket_vendors_screen.dart';

class BasketDetailScreen extends StatefulWidget {
  final BasketHeader basket;

  const BasketDetailScreen({
    super.key,
    required this.basket,
  });

  @override
  State<BasketDetailScreen> createState() => _BasketDetailScreenState();
}

class _BasketDetailScreenState extends State<BasketDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _currencyController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;

  DateTime _selectedDate = DateTime.now();
  DateTime? _expectedDeliveryDate;

  List<BasketItem> _basketItems = [];
  List<ManufacturerMaterial> _manufacturerMaterials = [];
  List<ManufacturerMaterial> _filteredMaterials = [];
  Map<String, Manufacturer> _manufacturersMap = {};
  Map<String, models.Material> _materialsMap = {};

  BasketHeader? _currentBasket;
  bool _isLoading = true;
  bool _showSearch = false;
  bool _isExistingRecord = false;

  bool get _isCreateMode => widget.basket.uuid.isEmpty;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.basket.description ?? '';
    _currencyController.text =
        widget.basket.currency.isEmpty ? 'INR' : widget.basket.currency;
    if (widget.basket.date.isNotEmpty) {
      _selectedDate = DateTime.tryParse(widget.basket.date) ?? DateTime.now();
    }
    if (widget.basket.expectedDeliveryDate != null) {
      _expectedDeliveryDate =
          DateTime.tryParse(widget.basket.expectedDeliveryDate!);
    } else if (_isCreateMode) {
      _expectedDeliveryDate = DateTime.now();
    }
    _loadData();
    _searchController.addListener(_filterMaterials);
    _descriptionController.addListener(_updateBasket);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _searchController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Auto-persist new baskets immediately (only if not already persisted)
    if (widget.basket.uuid.isEmpty && _currentBasket == null) {
      final now = DateTime.now().toIso8601String();
      final uuid = const Uuid().v4();
      final newBasket = BasketHeader(
        uuid: uuid,
        date: _selectedDate.toIso8601String().substring(0, 10),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        expectedDeliveryDate:
            _expectedDeliveryDate?.toIso8601String().substring(0, 10),
        currency: _currencyController.text.trim().isEmpty
            ? 'INR'
            : _currencyController.text.trim(),
        updatedAt: now,
      );
      await _dbHelper.insertBasketHeader(newBasket);
      // Reload from database to get the auto-generated ID
      final saved = await _dbHelper.getBasketHeader(uuid);
      _currentBasket = saved;
      _isExistingRecord = true;
    } else if (_currentBasket == null) {
      // Load existing basket from database
      final existing = await _dbHelper.getBasketHeader(widget.basket.uuid);
      _isExistingRecord = existing != null;
      if (existing != null) {
        _currentBasket = existing;
      }
    }

    // Load manufacturers and materials for search
    final manufacturers = await _dbHelper.getAllManufacturers();
    final materials = await _dbHelper.getAllMaterials();
    final manufacturerMaterials = await _dbHelper.getAllManufacturerMaterials();

    final manufacturersMap = {
      for (var m in manufacturers) m.uuid: m,
    };
    final materialsMap = {
      for (var m in materials) m.uuid: m,
    };

    // Load basket items using the current basket's UUID
    List<BasketItem> items = [];
    if (_isExistingRecord && _currentBasket != null) {
      items = await _dbHelper.getBasketItems(_currentBasket!.uuid);

      // Calculate total price and number of items
      final totalPrice =
          items.fold<double>(0.0, (sum, item) => sum + item.price);
      final numberOfItems = items.length;

      // Update basket header if totals have changed
      if (_currentBasket!.totalPrice != totalPrice ||
          _currentBasket!.numberOfItems != numberOfItems) {
        final updatedBasket = _currentBasket!.copyWith(
          totalPrice: totalPrice,
          numberOfItems: numberOfItems,
          updatedAt: DateTime.now().toIso8601String(),
        );
        await _dbHelper.updateBasketHeader(updatedBasket);
        _currentBasket = updatedBasket;
      }
    }

    setState(() {
      _manufacturersMap = manufacturersMap;
      _materialsMap = materialsMap;
      _manufacturerMaterials = manufacturerMaterials;
      _filteredMaterials = manufacturerMaterials;
      _basketItems = items;
      _isLoading = false;
    });
  }

  void _filterMaterials() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() {
        _filteredMaterials = _manufacturerMaterials;
      });
      return;
    }

    // Split query into words
    final queryWords = query.split(RegExp(r'\s+'));

    setState(() {
      _filteredMaterials = _manufacturerMaterials.where((mm) {
        final manufacturer = _manufacturersMap[mm.manufacturerUuid];
        final material = _materialsMap[mm.materialUuid];
        final manufacturerName = (manufacturer?.name ?? '').toLowerCase();
        final materialName = (material?.name ?? '').toLowerCase();
        final model = mm.model.toLowerCase();

        // Combine all searchable fields into one string
        final searchableText = '$manufacturerName $materialName $model';

        // Check if ALL query words are present in the searchable text
        return queryWords.every((word) => searchableText.contains(word));
      }).toList();
    });
  }

  Future<void> _updateBasket() async {
    if (_currentBasket == null || !_isExistingRecord) return;

    final basket = BasketHeader(
      uuid: _currentBasket!.uuid,
      id: _currentBasket!.id,
      date: _currentBasket!.date,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      expectedDeliveryDate: _currentBasket!.expectedDeliveryDate,
      totalPrice: _currentBasket!.totalPrice,
      currency: _currentBasket!.currency,
      numberOfItems: _currentBasket!.numberOfItems,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _dbHelper.updateBasketHeader(basket);
  }

  Future<void> _addManufacturerMaterialToBasket(ManufacturerMaterial mm) async {
    if (_currentBasket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the basket first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BasketItemDetailScreen(
          basketItem: BasketItem(
            uuid: '',
            basketUuid: _currentBasket!.uuid,
            manufacturerMaterialUuid: mm.uuid,
            materialUuid: mm.materialUuid,
            model: mm.model,
            manufacturerUuid: mm.manufacturerUuid,
            quantity: 1.0,
            unitOfMeasure: _materialsMap[mm.materialUuid]?.unitOfMeasure,
            maxRetailPrice: mm.maxRetailPrice,
            currency: _currencyController.text.trim().isEmpty
                ? 'INR'
                : _currencyController.text.trim(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
        ),
      ),
    );

    if (result != null) {
      _loadData();
      setState(() {
        _showSearch = false;
        _searchController.clear();
      });
    }
  }

  Future<void> _navigateToVendorQuotations() async {
    if (_currentBasket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please save the basket first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BasketVendorsScreen(basket: _currentBasket!),
      ),
    );

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.shopping_basket),
            const SizedBox(width: 8),
            Text(
              _currentBasket?.id != null
                  ? '#${_currentBasket!.id} - ${DateFormat('dd-MMM-yy').format(_selectedDate)}'
                  : DateFormat('dd-MMM-yy').format(_selectedDate),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!_showSearch) ...[
                  // Basket header form
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First row: Expected Delivery Date, Currency
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _expectedDeliveryDate ??
                                              DateTime.now().add(
                                                const Duration(days: 7),
                                              ),
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
                                        decoration: const InputDecoration(
                                          labelText: 'Expected Delivery',
                                          border: OutlineInputBorder(),
                                          suffixIcon:
                                              Icon(Icons.calendar_today),
                                        ),
                                        child: Text(
                                          _expectedDeliveryDate != null
                                              ? DateFormat('dd-MMM-yyyy')
                                                  .format(
                                                      _expectedDeliveryDate!)
                                              : 'Not set',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _currencyController,
                                      decoration: const InputDecoration(
                                        labelText: 'Currency',
                                        border: OutlineInputBorder(),
                                        hintText: 'INR',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Second row: Description
                              TextFormField(
                                controller: _descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Third row: Number of Items, Total Price
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Number of Items',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_currentBasket?.numberOfItems ?? 0}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Total Price',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_currencyController.text} ${(_currentBasket?.totalPrice ?? 0.0).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              // Vendor Quotations button
                              if (_currentBasket != null &&
                                  _basketItems.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _navigateToVendorQuotations,
                                    icon: const Icon(Icons.compare_arrows),
                                    label:
                                        const Text('Compare Vendor Quotations'),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              // Items section
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Items',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _currentBasket == null
                                        ? null
                                        : () {
                                            setState(() {
                                              _showSearch = true;
                                            });
                                          },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Item'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_basketItems.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text(
                                      'No items yet. Add items to your basket.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                )
                              else
                                ..._basketItems
                                    .map((item) => _buildBasketItemCard(item)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_showSearch) ...[
                  // Search UI
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              labelText: 'Search materials',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _showSearch = false;
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _filteredMaterials.isEmpty
                        ? const Center(
                            child: Text('No materials found'),
                          )
                        : ListView.builder(
                            itemCount: _filteredMaterials.length,
                            itemBuilder: (context, index) {
                              final mm = _filteredMaterials[index];
                              final manufacturer =
                                  _manufacturersMap[mm.manufacturerUuid];
                              final material = _materialsMap[mm.materialUuid];

                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  title: Text(
                                    '${manufacturer?.name ?? ''} - ${mm.model}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(material?.name ?? ''),
                                      if (mm.maxRetailPrice != null)
                                        Text(
                                          'MRP: ${mm.currency ?? 'INR'} ${mm.maxRetailPrice!.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.add_circle),
                                  onTap: () =>
                                      _addManufacturerMaterialToBasket(mm),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildBasketItemCard(BasketItem item) {
    final manufacturer = _manufacturersMap[item.manufacturerUuid];
    final material = _materialsMap[item.materialUuid];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BasketItemDetailScreen(basketItem: item),
            ),
          );
          _loadData();
        },
        title: Text(
          '${manufacturer?.name ?? ''} - ${material?.name ?? ''} - ${item.model ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Qty: ${item.quantity.toStringAsFixed(2)} ${item.unitOfMeasure ?? ''} * ${item.price.toStringAsFixed(2)} ${item.currency}',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BasketItemDetailScreen(basketItem: item),
                  ),
                );
                if (result != null) {
                  _loadData();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: const Text(
                      'Are you sure you want to delete this item?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _dbHelper.deleteBasketItem(item.uuid);
                  _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
