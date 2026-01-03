import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/basket_header.dart';
import '../models/basket_vendor.dart';
import '../models/vendor.dart';
import '../services/database_helper.dart';
import 'basket_vendor_detail_screen.dart';

class BasketVendorsScreen extends StatefulWidget {
  final BasketHeader basket;

  const BasketVendorsScreen({
    super.key,
    required this.basket,
  });

  @override
  State<BasketVendorsScreen> createState() => _BasketVendorsScreenState();
}

class _BasketVendorsScreenState extends State<BasketVendorsScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<BasketVendor> _basketVendors = [];
  List<Vendor> _availableVendors = [];
  Map<String, Vendor> _vendorsMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final vendors = await _dbHelper.getAllVendors();
    final basketVendors = await _dbHelper.getBasketVendors(widget.basket.uuid);

    final vendorsMap = {
      for (var v in vendors) v.uuid: v,
    };

    // Get vendors not yet in this basket
    final usedVendorUuids = basketVendors.map((bv) => bv.vendorUuid).toSet();
    final availableVendors =
        vendors.where((v) => !usedVendorUuids.contains(v.uuid)).toList();

    // Sort basket vendors by total amount (best price first)
    basketVendors.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));

    setState(() {
      _basketVendors = basketVendors;
      _availableVendors = availableVendors;
      _vendorsMap = vendorsMap;
      _isLoading = false;
    });
  }

  Future<void> _addVendorQuotation() async {
    if (_availableVendors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All vendors have been added'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show vendor selection dialog
    final selectedVendor = await showDialog<Vendor>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Vendor'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableVendors.length,
            itemBuilder: (context, index) {
              final vendor = _availableVendors[index];
              return ListTile(
                title: Text(vendor.name),
                subtitle: vendor.description != null
                    ? Text(vendor.description!)
                    : null,
                onTap: () => Navigator.pop(context, vendor),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedVendor != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BasketVendorDetailScreen(
            basketVendor: BasketVendor(
              uuid: '',
              basketUuid: widget.basket.uuid,
              vendorUuid: selectedVendor.uuid,
              date: DateTime.now().toIso8601String().substring(0, 10),
              expectedDeliveryDate: widget.basket.expectedDeliveryDate,
              currency: widget.basket.currency,
              updatedAt: DateTime.now().toIso8601String(),
            ),
          ),
        ),
      );

      // Always reload to update the available vendors list
      _loadData();
    }
  }

  Future<bool> _confirmDeleteVendorQuotation(BasketVendor bv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete quotation from ${_vendorsMap[bv.vendorUuid]?.name ?? "vendor"}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbHelper.deleteBasketVendor(bv.uuid);

      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor quotation deleted'),
        ),
      );

      _loadData();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Quotations'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Basket Info Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basket #${widget.basket.id ?? ''}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.basket.numberOfItems} items • ${widget.basket.currency} ${widget.basket.totalPrice.toStringAsFixed(2)} (MRP)',
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _basketVendors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.request_quote,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                'No vendor quotations yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap + to add vendor quotations',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _basketVendors.length,
                          itemBuilder: (context, index) {
                            final bv = _basketVendors[index];
                            return _buildVendorQuotationCard(bv, index);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addVendorQuotation,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVendorQuotationCard(BasketVendor bv, int index) {
    final vendor = _vendorsMap[bv.vendorUuid];
    final dateFormat = DateFormat('dd-MMM-yyyy');
    final date = DateTime.tryParse(bv.date);
    final dateStr = date != null ? dateFormat.format(date) : bv.date;

    // Highlight best price
    final isBestPrice = index == 0 && _basketVendors.length > 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: isBestPrice ? 4 : 1,
      color: isBestPrice ? Colors.green.shade50 : null,
      child: Column(
        children: [
          if (isBestPrice)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: const Center(
                child: Text(
                  '🏆 BEST PRICE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  isBestPrice ? Colors.green.shade700 : Colors.blue,
              child: Text(
                '${bv.id ?? ''}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              vendor?.name ?? 'Unknown Vendor',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isBestPrice ? Colors.green.shade900 : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Date: $dateStr'),
                if (bv.expectedDeliveryDate != null) ...[
                  const SizedBox(height: 2),
                  Text('Expected: ${_formatDate(bv.expectedDeliveryDate!)}'),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text('${bv.numberOfAvailableItems} available'),
                    if (bv.numberOfUnavailableItems > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.cancel,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text('${bv.numberOfUnavailableItems} unavailable'),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Base: ${bv.currency} ${bv.basePrice.toStringAsFixed(2)} + Tax: ${bv.taxAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  'Total: ${bv.currency} ${bv.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isBestPrice
                        ? Colors.green.shade900
                        : Colors.blue.shade900,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteVendorQuotation(bv),
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BasketVendorDetailScreen(basketVendor: bv),
                ),
              );
              // Always reload to refresh vendor data
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final dateFormat = DateFormat('dd-MMM-yyyy');
    final date = DateTime.tryParse(dateStr);
    return date != null ? dateFormat.format(date) : dateStr;
  }
}
