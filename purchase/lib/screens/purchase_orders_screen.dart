import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/purchase_order.dart';
import '../services/database_helper.dart';
import 'purchase_order_detail_screen.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _dbHelper = DatabaseHelper.instance;
  List<PurchaseOrder> _purchaseOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPurchaseOrders();
  }

  Future<void> _loadPurchaseOrders() async {
    setState(() {
      _isLoading = true;
    });

    final purchaseOrders = await _dbHelper.getAllPurchaseOrders();

    setState(() {
      _purchaseOrders = purchaseOrders;
      _isLoading = false;
    });
  }

  Future<void> _deletePurchaseOrder(PurchaseOrder purchaseOrder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Order'),
        content: Text(
            'Are you sure you want to delete Purchase Order #${purchaseOrder.id ?? 'N/A'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _dbHelper.deletePurchaseOrder(purchaseOrder.uuid);
      _loadPurchaseOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase Order deleted')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _purchaseOrders.isEmpty
              ? RefreshIndicator(
                  onRefresh: _loadPurchaseOrders,
                  child: ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(
                        child:
                            Text('No purchase orders found. Tap + to add one.'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPurchaseOrders,
                  child: ListView.builder(
                    itemCount: _purchaseOrders.length,
                    itemBuilder: (context, index) {
                      final po = _purchaseOrders[index];
                      return FutureBuilder(
                        future: _dbHelper.getVendor(po.vendorUuid),
                        builder: (context, snapshot) {
                          final vendor = snapshot.data;
                          return Dismissible(
                            key: Key(po.uuid),
                            direction: po.completed
                                ? DismissDirection.none
                                : DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              await _deletePurchaseOrder(po);
                              return false;
                            },
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                title: Text(
                                  '#${po.id ?? 'N/A'} | Vendor: ${vendor?.name ?? 'Unknown'}',
                                  style: TextStyle(
                                    color: po.completed
                                        ? Colors.brown.shade800
                                        : null,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${DateFormat('yyyy-MM-dd').format(po.orderDate)} | Total: ${po.totalAmount.toStringAsFixed(2)} ${po.currency ?? ''}',
                                    ),
                                    const SizedBox(height: 2),
                                    RichText(
                                      text: TextSpan(
                                        style:
                                            DefaultTextStyle.of(context).style,
                                        children: [
                                          const TextSpan(text: 'Paid: '),
                                          TextSpan(
                                            text:
                                                '${po.amountPaid.toStringAsFixed(2)} ${po.currency ?? ''}',
                                            style: const TextStyle(
                                                color: Colors.green),
                                          ),
                                          const TextSpan(text: ' | Balance: '),
                                          TextSpan(
                                            text:
                                                '${po.amountBalance.toStringAsFixed(2)} ${po.currency ?? ''}',
                                            style: TextStyle(
                                              color: po.amountBalance > 0
                                                  ? Colors.orange
                                                  : Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: po.completed
                                    ? null
                                    : IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () =>
                                            _deletePurchaseOrder(po),
                                      ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PurchaseOrderDetailScreen(
                                        purchaseOrder: po,
                                      ),
                                    ),
                                  );
                                  _loadPurchaseOrders();
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          final vendors = await _dbHelper.getAllVendors();
          if (vendors.isEmpty) {
            if (!mounted) return;
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Please add vendors first.'),
              ),
            );
            return;
          }

          final newPurchaseOrder = PurchaseOrder(
            uuid: const Uuid().v4(),
            vendorUuid: vendors.first.uuid,
            date: DateTime.now(),
            basePrice: 0.0,
            taxAmount: 0.0,
            totalAmount: 0.0,
            currency: 'INR',
            orderDate: DateTime.now(),
            expectedDeliveryDate: DateTime.now(),
            updatedAt: DateTime.now().toUtc(),
          );
          if (!mounted) return;
          await navigator.push(
            MaterialPageRoute(
              builder: (_) => PurchaseOrderDetailScreen(
                purchaseOrder: newPurchaseOrder,
              ),
            ),
          );
          if (mounted) {
            _loadPurchaseOrders();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
