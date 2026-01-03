import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/basket_item.dart';
import '../models/manufacturer_material.dart';
import '../models/manufacturer.dart';
import '../models/material.dart' as models;
import '../services/database_helper.dart';

class BasketItemDetailScreen extends StatefulWidget {
  final BasketItem basketItem;

  const BasketItemDetailScreen({
    super.key,
    required this.basketItem,
  });

  @override
  State<BasketItemDetailScreen> createState() => _BasketItemDetailScreenState();
}

class _BasketItemDetailScreenState extends State<BasketItemDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _dbHelper = DatabaseHelper.instance;

  ManufacturerMaterial? _manufacturerMaterial;
  Manufacturer? _manufacturer;
  models.Material? _material;

  BasketItem? _currentBasketItem;
  bool _isLoading = true;
  bool _isExistingRecord = false;

  double _calculatedPrice = 0.0;

  bool get _isCreateMode => widget.basketItem.uuid.isEmpty;

  @override
  void initState() {
    super.initState();
    _quantityController.text = widget.basketItem.quantity.toString();
    _loadData();
    _quantityController.addListener(_updateBasketItem);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    // Auto-persist new basket items immediately
    if (widget.basketItem.uuid.isEmpty) {
      final now = DateTime.now().toIso8601String();
      final uuid = const Uuid().v4();
      final quantity = double.tryParse(_quantityController.text) ?? 1.0;
      final mrp = widget.basketItem.maxRetailPrice ?? 0.0;
      final calculatedPrice = quantity * mrp;

      final newItem = BasketItem(
        uuid: uuid,
        basketUuid: widget.basketItem.basketUuid,
        manufacturerMaterialUuid: widget.basketItem.manufacturerMaterialUuid,
        materialUuid: widget.basketItem.materialUuid,
        model: widget.basketItem.model,
        manufacturerUuid: widget.basketItem.manufacturerUuid,
        quantity: quantity,
        unitOfMeasure: widget.basketItem.unitOfMeasure,
        maxRetailPrice: widget.basketItem.maxRetailPrice,
        price: calculatedPrice,
        currency: widget.basketItem.currency,
        updatedAt: now,
      );
      await _dbHelper.insertBasketItem(newItem);
      // Reload from database to get the auto-generated ID
      final saved = await _dbHelper.getBasketItem(uuid);
      _currentBasketItem = saved;
      _isExistingRecord = true;
    } else {
      // Check if record exists in database
      final existing = await _dbHelper.getBasketItem(widget.basketItem.uuid);
      _isExistingRecord = existing != null;
      if (existing != null) {
        _currentBasketItem = existing;
      }
    }

    // Load related data
    final mm = await _dbHelper.getManufacturerMaterial(
      widget.basketItem.manufacturerMaterialUuid,
    );

    Manufacturer? manufacturer;
    models.Material? material;

    if (mm != null) {
      manufacturer = await _dbHelper.getManufacturer(mm.manufacturerUuid);
      material = await _dbHelper.getMaterial(mm.materialUuid);
    }

    setState(() {
      _manufacturerMaterial = mm;
      _manufacturer = manufacturer;
      _material = material;
      _isLoading = false;
    });

    _calculatePrice();
  }

  void _calculatePrice() {
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    final mrp = _manufacturerMaterial?.maxRetailPrice ?? 0.0;

    setState(() {
      _calculatedPrice = quantity * mrp;
    });
  }

  Future<void> _updateBasketItem() async {
    if (_currentBasketItem == null || !_isExistingRecord) return;

    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    if (quantity <= 0) return;

    _calculatePrice();

    final item = BasketItem(
      uuid: _currentBasketItem!.uuid,
      id: _currentBasketItem!.id,
      basketUuid: _currentBasketItem!.basketUuid,
      manufacturerMaterialUuid: _currentBasketItem!.manufacturerMaterialUuid,
      materialUuid: _currentBasketItem!.materialUuid,
      model: _currentBasketItem!.model,
      manufacturerUuid: _currentBasketItem!.manufacturerUuid,
      quantity: quantity,
      unitOfMeasure: _currentBasketItem!.unitOfMeasure,
      maxRetailPrice: _currentBasketItem!.maxRetailPrice,
      price: _calculatedPrice,
      currency: _currentBasketItem!.currency,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await _dbHelper.updateBasketItem(item);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          Navigator.of(context).pop(_currentBasketItem);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isCreateMode ? 'Add Basket Item' : 'Edit Basket Item'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.of(context).pop(_currentBasketItem);
            },
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
                      // Material Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Material',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Manufacturer:',
                                _manufacturer?.name ?? '',
                              ),
                              _buildInfoRow(
                                'Model:',
                                _manufacturerMaterial?.model ?? '',
                              ),
                              _buildInfoRow(
                                'Material:',
                                _material?.name ?? '',
                              ),
                              _buildInfoRow(
                                'Unit:',
                                _material?.unitOfMeasure ?? '',
                              ),
                              if (_manufacturerMaterial?.maxRetailPrice != null)
                                _buildInfoRow(
                                  'MRP per unit:',
                                  '${widget.basketItem.currency} ${_manufacturerMaterial!.maxRetailPrice!.toStringAsFixed(2)}',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quantity
                      TextFormField(
                        controller: _quantityController,
                        decoration: InputDecoration(
                          labelText: 'Quantity',
                          border: const OutlineInputBorder(),
                          suffixText: _material?.unitOfMeasure ?? '',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter quantity';
                          }
                          final quantity = double.tryParse(value);
                          if (quantity == null || quantity <= 0) {
                            return 'Please enter a valid quantity';
                          }
                          return null;
                        },
                        onChanged: (_) => _calculatePrice(),
                      ),
                      const SizedBox(height: 24),

                      // Price Summary Card
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Price',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${widget.basketItem.currency} ${_calculatedPrice.toStringAsFixed(2)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                  ),
                                ],
                              ),
                              if (_manufacturerMaterial?.maxRetailPrice !=
                                      null &&
                                  double.tryParse(_quantityController.text) !=
                                      null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '${_quantityController.text} × ${_manufacturerMaterial!.maxRetailPrice!.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
