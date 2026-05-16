// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_checkin_screen.dart';
import './edit_product_screen.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';

import 'dart:async';

// ─── Invoice Item Model ───────────────────────────────────────────────────────

class InvoiceRecord {
  final String id;
  final String invoiceNumber;
  final String supplierName;
  final String deliveryDate;
  final String invoiceTotal;
  final String itemCode;
  final String description;
  final String quantity;
  final String batchNo;
  final String expiryDate;
  final String amount;
  final DateTime? createdAt;
  final String createdBy;

  InvoiceRecord({
    required this.id,
    required this.invoiceNumber,
    required this.supplierName,
    required this.deliveryDate,
    required this.invoiceTotal,
    required this.itemCode,
    required this.description,
    required this.quantity,
    required this.batchNo,
    required this.expiryDate,
    required this.amount,
    this.createdAt,
    required this.createdBy,
  });

  factory InvoiceRecord.fromMap(String id, Map<String, dynamic> data) =>
      InvoiceRecord(
        id: id,
        invoiceNumber: data['invoiceNumber']?.toString() ?? '',
        supplierName: data['supplierName']?.toString() ?? '',
        deliveryDate: data['deliveryDate']?.toString() ?? '',
        invoiceTotal: data['invoiceTotal']?.toString() ?? '',
        itemCode: data['itemCode']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        quantity: data['quantity']?.toString() ?? '',
        batchNo: data['batchNo']?.toString() ?? '',
        expiryDate: data['expiryDate']?.toString() ?? '',
        amount: data['amount']?.toString() ?? '',
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
        createdBy: data['createdBy']?.toString() ?? '',
      );

  /// Parse expiry into a DateTime for sorting. Falls back to far future if unparseable.
  DateTime get parsedExpiry {
    if (expiryDate.isEmpty) return DateTime(9999);
    final iso = DateTime.tryParse(expiryDate);
    if (iso != null) return iso;
    try {
      final parts = expiryDate.split(RegExp(r'[\/\-]'));
      if (parts.length == 3) {
        final nums = parts.map((p) => int.tryParse(p) ?? 0).toList();
        // MM/DD/YYYY
        if (nums[2] > 99) return DateTime(nums[2], nums[0], nums[1]);
        // DD/MM/YY
        return DateTime(2000 + nums[2], nums[1], nums[0]);
      }
      if (parts.length == 2) {
        final a = int.tryParse(parts[0]) ?? 1;
        final b = int.tryParse(parts[1]) ?? 2025;
        if (b > 99) return DateTime(b, a);
        if (a > 12) return DateTime(2000 + a, b);
        return DateTime(2000 + b, a);
      }
    } catch (_) {}
    return DateTime(9999);
  }

  bool get isExpired => parsedExpiry.isBefore(DateTime.now());

  bool get isExpiringSoon {
    final diff = parsedExpiry.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 180;
  }
}

class GroupedInvoice {
  final String invoiceNumber;
  final String supplierName;
  final String deliveryDate;
  final String invoiceTotal;
  final List<InvoiceRecord> items;
  final DateTime? scannedAt;

  GroupedInvoice({
    required this.invoiceNumber,
    required this.supplierName,
    required this.deliveryDate,
    required this.invoiceTotal,
    required this.items,
    this.scannedAt,
  });
}

// ─── Dashboard ────────────────────────────────────────────────────────────────

class PharmaDashboard extends StatefulWidget {
  const PharmaDashboard({super.key});

  @override
  State<PharmaDashboard> createState() => _PharmaDashboardState();
}

class _PharmaDashboardState extends State<PharmaDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  StreamSubscription? _productSubscription;
  StreamSubscription? _invoiceSubscription;

  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;

  List<Product> products = [];
  List<InvoiceRecord> _allInvoiceRecords = [];

  bool _isLoading = true;
  bool _invoicesLoading = true;

  String _productSearch = '';
  String _invoiceSearch = '';
  String _medicineSearch = '';

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _listenToProducts();
    _listenToInvoices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _productSubscription?.cancel();
    _invoiceSubscription?.cancel();
    super.dispose();
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  void _listenToProducts() {
    _productSubscription?.cancel();
    _productSubscription = _firestoreService.getProducts().listen(
      (data) => setState(() {
        products = data;
        _isLoading = false;
      }),
      onError: (_) => setState(() => _isLoading = false),
    );
  }

  void _listenToInvoices() {
    _invoiceSubscription?.cancel();
    _invoiceSubscription = FirebaseFirestore.instance
        .collection('invoice_items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snap) => setState(() {
        _allInvoiceRecords = snap.docs
            .map((d) => InvoiceRecord.fromMap(d.id, d.data()))
            .toList();
        _invoicesLoading = false;
      }),
      onError: (_) => setState(() => _invoicesLoading = false),
    );
  }

  // ─── Return window helpers ────────────────────────────────────────────────

  List<Product> get _windowClosedProducts => products
      .where((p) =>
          p.returnWindowStatus == ReturnWindowStatus.windowClosed &&
          p.returnStatus != ReturnStatus.completed)
      .toList();

  List<Product> get _returnSoonProducts => products
      .where((p) =>
          p.returnWindowStatus == ReturnWindowStatus.returnSoon &&
          p.returnStatus != ReturnStatus.completed)
      .toList();

  List<Product> get _returnableProducts => products
      .where((p) =>
          p.isReturnable && p.returnStatus != ReturnStatus.completed)
      .toList()
    ..sort((a, b) =>
        a.daysUntilReturnDeadline.compareTo(b.daysUntilReturnDeadline));

  int get _urgentReturnCount =>
      _returnSoonProducts.length + _windowClosedProducts.length;

  // ─── Product helpers ──────────────────────────────────────────────────────

  List<Product> get filteredProducts {
    final q = _productSearch.toLowerCase();
    if (q.isEmpty) return products;
    return products.where((p) =>
        p.genericName.toLowerCase().contains(q) ||
        p.brandName.toLowerCase().contains(q) ||
        p.supplierName.toLowerCase().contains(q)).toList();
  }

  Color _windowStatusColor(ReturnWindowStatus s) {
    switch (s) {
      case ReturnWindowStatus.returnable:  return Colors.green;
      case ReturnWindowStatus.returnSoon:  return Colors.orange;
      case ReturnWindowStatus.windowClosed: return Colors.red;
      case ReturnWindowStatus.expired:     return Colors.grey;
    }
  }

  String _windowStatusLabel(ReturnWindowStatus s) {
    switch (s) {
      case ReturnWindowStatus.returnable:  return 'Returnable';
      case ReturnWindowStatus.returnSoon:  return 'Return Soon';
      case ReturnWindowStatus.windowClosed: return 'Window Closed';
      case ReturnWindowStatus.expired:     return 'Expired';
    }
  }

  // ─── Invoice helpers ──────────────────────────────────────────────────────

  List<GroupedInvoice> get _groupedInvoices {
    final Map<String, List<InvoiceRecord>> map = {};
    for (final r in _allInvoiceRecords) {
      final key = r.invoiceNumber.isNotEmpty ? r.invoiceNumber : r.id;
      map.putIfAbsent(key, () => []).add(r);
    }
    final list = map.entries.map((e) {
      final items = e.value;
      final first = items.first;
      return GroupedInvoice(
        invoiceNumber: first.invoiceNumber,
        supplierName: first.supplierName,
        deliveryDate: first.deliveryDate,
        invoiceTotal: first.invoiceTotal,
        items: items,
        scannedAt: first.createdAt,
      );
    }).toList()
      ..sort((a, b) {
        if (a.scannedAt == null) return 1;
        if (b.scannedAt == null) return -1;
        return b.scannedAt!.compareTo(a.scannedAt!);
      });

    if (_invoiceSearch.isEmpty) return list;
    final q = _invoiceSearch.toLowerCase();
    return list
        .where((g) =>
            g.supplierName.toLowerCase().contains(q) ||
            g.invoiceNumber.toLowerCase().contains(q))
        .toList();
  }

  double get _totalInvoiceSpend {
    final seen = <String>{};
    double total = 0;
    for (final r in _allInvoiceRecords) {
      final key = r.invoiceNumber.isNotEmpty ? r.invoiceNumber : r.id;
      if (seen.add(key)) total += double.tryParse(r.invoiceTotal) ?? 0;
    }
    return total;
  }

  // ─── Medicine helpers ─────────────────────────────────────────────────────

  List<InvoiceRecord> get _sortedMedicines {
    final q = _medicineSearch.toLowerCase();
    var list = q.isEmpty
        ? List<InvoiceRecord>.from(_allInvoiceRecords)
        : _allInvoiceRecords
            .where((r) =>
                r.description.toLowerCase().contains(q) ||
                r.supplierName.toLowerCase().contains(q) ||
                r.batchNo.toLowerCase().contains(q) ||
                r.itemCode.toLowerCase().contains(q))
            .toList();
    list.sort((a, b) => a.parsedExpiry.compareTo(b.parsedExpiry));
    return list;
  }

  int get _expiredMedicineCount =>
      _allInvoiceRecords.where((r) => r.isExpired).length;

  int get _expiringSoonMedicineCount =>
      _allInvoiceRecords.where((r) => r.isExpiringSoon && !r.isExpired).length;

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  void _showDeleteProductConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.delete_outline, color: Colors.red),
          ),
          const SizedBox(width: 12),
          const Text('Delete Product',
              style: TextStyle(color: Colors.red, fontSize: 16)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            children: [
              const TextSpan(text: 'Delete '),
              TextSpan(
                  text: product.genericName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (product.brandName.isNotEmpty)
                TextSpan(text: ' (${product.brandName})'),
              const TextSpan(text: '? This cannot be undone.'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () {
              _firestoreService.deleteProduct(product.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_forever, color: Colors.white, size: 16),
            label: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _markReturnInitiated(Product product) async {
    await _firestoreService.updateReturnStatus(product.id, ReturnStatus.pending);
    _showSnack('${product.genericName} marked for return.');
  }

  Future<void> _deleteInvoiceGroup(GroupedInvoice group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Invoice',
            style: TextStyle(color: Colors.red, fontSize: 16)),
        content: Text(
          'Delete invoice from ${group.supplierName}?\n'
          'This removes all ${group.items.length} line item(s).',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in group.items) {
      batch.delete(
          FirebaseFirestore.instance.collection('invoice_items').doc(item.id));
    }
    await batch.commit();
    _showSnack('Invoice deleted.');
  }

  Future<void> _deleteInvoiceItem(InvoiceRecord record) async {
    await FirebaseFirestore.instance
        .collection('invoice_items')
        .doc(record.id)
        .delete();
    _showSnack('Item removed.');
  }

  void _showEditItemSheet(InvoiceRecord record) {
    final controllers = {
      'description': TextEditingController(text: record.description),
      'quantity':    TextEditingController(text: record.quantity),
      'amount':      TextEditingController(text: record.amount),
      'batchNo':     TextEditingController(text: record.batchNo),
      'expiryDate':  TextEditingController(text: record.expiryDate),
      'itemCode':    TextEditingController(text: record.itemCode),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => PopScope(
        onPopInvokedWithResult: (_, __) {
          for (final c in controllers.values) c.dispose();
        },
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16, right: 16, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit Medicine',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1))),
                const SizedBox(height: 4),
                Text(
                  record.invoiceNumber.isNotEmpty
                      ? 'Invoice: ${record.invoiceNumber}'
                      : 'No invoice number',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                _sheetField(controllers['description']!, 'Description'),
                Row(children: [
                  Expanded(child: _sheetField(controllers['quantity']!, 'Quantity')),
                  const SizedBox(width: 8),
                  Expanded(child: _sheetField(controllers['amount']!, 'Amount (₱)')),
                ]),
                Row(children: [
                  Expanded(child: _sheetField(controllers['batchNo']!, 'Batch / Lot No.')),
                  const SizedBox(width: 8),
                  Expanded(child: _sheetField(controllers['expiryDate']!, 'Expiry Date')),
                ]),
                _sheetField(controllers['itemCode']!, 'Item Code'),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('invoice_items')
                          .doc(record.id)
                          .update({
                        'description': controllers['description']!.text,
                        'quantity':    controllers['quantity']!.text,
                        'amount':      controllers['amount']!.text,
                        'batchNo':     controllers['batchNo']!.text,
                        'expiryDate':  controllers['expiryDate']!.text,
                        'itemCode':    controllers['itemCode']!.text,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      for (final c in controllers.values) c.dispose();
                      _showSnack('Medicine updated.');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Changes',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Snack ────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: const Color(0xFF0D47A1),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF0D47A1),
                      indicatorWeight: 3,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        // ── Inventory ──
                        const Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2, size: 15),
                              SizedBox(width: 5),
                              Text('Inventory', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        // ── Returns ──
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment_return, size: 15),
                              const SizedBox(width: 5),
                              const Text('Returns', style: TextStyle(fontSize: 12)),
                              if (_urgentReturnCount > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text('$_urgentReturnCount',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // ── Medicines ──

                        // ── Invoices ──
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long, size: 15),
                              const SizedBox(width: 5),
                              const Text('Invoices', style: TextStyle(fontSize: 12)),
                              if (_allInvoiceRecords.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF0D47A1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Text('${_groupedInvoices.length}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildInventoryTab(),
                  _buildReturnsTab(),
                  _buildInvoicesTab(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddCheckInScreen())),
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Check In', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF2196F3)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Welcome,',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                        Text(
                          user?.displayName ?? user?.email ?? 'User',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_urgentReturnCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_urgentReturnCount urgent',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
              
                    _headerPill(
                        DateFormat('MMM d, yyyy').format(DateTime.now()),
                        Icons.calendar_today),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Inventory Tab ────────────────────────────────────────────────────────

Widget _buildInventoryTab() {
  if (_invoicesLoading) {
    return const Center(child: CircularProgressIndicator());
  }

  final medicines = _sortedMedicines;
  final expiredCount = medicines.where((r) => r.isExpired).length;
  final soonCount = medicines.where((r) => r.isExpiringSoon && !r.isExpired).length;

  return RefreshIndicator(
    onRefresh: () async => _listenToInvoices(),
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Summary cards ──
        Row(children: [
          Expanded(
              child: _medStatCard('${medicines.length}', 'Total',
                  Icons.medication, const Color(0xFF0D47A1))),
          const SizedBox(width: 8),
          Expanded(
              child: _medStatCard('$soonCount', 'Expiring Soon',
                  Icons.timer_outlined, Colors.orange)),
          const SizedBox(width: 8),
          Expanded(
              child: _medStatCard('$expiredCount', 'Expired',
                  Icons.warning_amber, Colors.red)),
        ]),
        const SizedBox(height: 14),

        // ── Search ──
        TextField(
          decoration: InputDecoration(
            hintText: 'Search medicine, supplier, batch...',
            prefixIcon:
                const Icon(Icons.search, color: Color(0xFF0D47A1)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0D47A1), width: 1)),
          ),
          onChanged: (v) => setState(() => _medicineSearch = v),
        ),
        const SizedBox(height: 12),

        if (medicines.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.medication, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No medicines found',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Tap Check In to scan an invoice',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
          )
        else
          ...medicines.map((r) => _buildMedicineCard(r)),

        const SizedBox(height: 100),
      ],
    ),
  );
}

  Widget _buildProductCard(Product product) {
    final ws = product.returnWindowStatus;
    final wsColor = _windowStatusColor(ws);
    final wsLabel = _windowStatusLabel(ws);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Slidable(
          startActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              SlidableAction(
                onPressed: (_) => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EditProductScreen(product: product))),
                icon: Icons.edit,
                backgroundColor: Colors.blue,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12)),
              ),
              SlidableAction(
                onPressed: (_) => _showDeleteProductConfirmation(product),
                icon: Icons.delete,
                backgroundColor: Colors.red,
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 1,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showProductDetails(product),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 52,
                      decoration: BoxDecoration(
                        color: wsColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product.genericName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          if (product.brandName.isNotEmpty)
                            Text(product.brandName,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic)),
                          const SizedBox(height: 2),
                          Text(
                            '${product.supplierName}  •  Exp: ${product.expiryDate}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: wsColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(wsLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: wsColor)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ws == ReturnWindowStatus.expired
                              ? 'Expired'
                              : ws == ReturnWindowStatus.windowClosed
                                  ? 'Deadline passed'
                                  : '${product.daysUntilReturnDeadline}d to deadline',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProductDetails(Product product) async {
    final ws = product.returnWindowStatus;
    final wsColor = _windowStatusColor(ws);
    final creatorName =
        await _firestoreService.getUserName(product.createdBy);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.genericName,
                style: const TextStyle(
                    color: Color(0xFF0D47A1), fontSize: 16)),
            if (product.brandName.isNotEmpty)
              Text(product.brandName,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.normal)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: wsColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: wsColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_windowStatusLabel(ws),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: wsColor)),
                    const SizedBox(height: 2),
                    Text(
                      'Return deadline: ${DateFormat('MMM d, yyyy').format(product.returnDeadline)}',
                      style: TextStyle(fontSize: 11, color: wsColor),
                    ),
                    if (ws != ReturnWindowStatus.expired)
                      Text(
                        ws == ReturnWindowStatus.windowClosed
                            ? 'Return window has closed — ${(-product.daysUntilReturnDeadline)} days ago'
                            : '${product.daysUntilReturnDeadline} day(s) remaining in return window',
                        style: TextStyle(fontSize: 11, color: wsColor),
                      ),
                  ],
                ),
              ),
              _detailRow('Supplier', product.supplierName),
              _detailRow('Dosage Form', product.dosageForm),
              _detailRow('Expiry Date', product.expiryDate),
              _detailRow('Stock Status', product.stockStatus),
              if (product.sellingPrice.isNotEmpty &&
                  product.sellingPrice != '0.00')
                _detailRow('Selling Price', '₱${product.sellingPrice}'),
              if (product.note.isNotEmpty) _detailRow('Note', product.note),
              if (product.createdAt != null)
                _detailRow('Logged On',
                    DateFormat('MMM dd, yyyy – hh:mm a').format(product.createdAt!)),
              _detailRow('Added By', creatorName),
              if (product.returnStatus != ReturnStatus.none)
                _detailRow(
                    'Return Status', product.returnStatus.name.toUpperCase()),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          if (product.isReturnable &&
              product.returnStatus != ReturnStatus.pending)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markReturnInitiated(product);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.assignment_return,
                  color: Colors.white, size: 16),
              label: const Text('Mark for Return',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(
              child: Text(value,
                  style: TextStyle(fontSize: 12, color: valueColor))),
        ],
      ),
    );
  }

  // ─── Returns Tab ──────────────────────────────────────────────────────────

  Widget _buildReturnsTab() {
    final closedSoon = _returnSoonProducts;
    final closed = _windowClosedProducts;
    final returnable = _returnableProducts
        .where((p) => p.returnWindowStatus == ReturnWindowStatus.returnable)
        .toList();

    return RefreshIndicator(
      onRefresh: () async => _listenToProducts(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
                child: _returnStatCard('${returnable.length}', 'Returnable',
                    Colors.green, Icons.check_circle_outline)),
            const SizedBox(width: 10),
            Expanded(
                child: _returnStatCard('${closedSoon.length}', 'Return Soon',
                    Colors.orange, Icons.timer_outlined)),
            const SizedBox(width: 10),
            Expanded(
                child: _returnStatCard('${closed.length}', 'Window Closed',
                    Colors.red, Icons.block)),
          ]),
          const SizedBox(height: 20),

          if (closedSoon.isNotEmpty) ...[
            _sectionLabel('⚠ RETURN WINDOW CLOSING SOON', Colors.orange),
            const SizedBox(height: 6),
            const Text(
              'These products have less than 30 days before the return window closes. Act now.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ...closedSoon.map((p) => _returnWindowCard(p)),
            const SizedBox(height: 20),
          ],

          if (closed.isNotEmpty) ...[
            _sectionLabel('✕ RETURN WINDOW CLOSED', Colors.red),
            const SizedBox(height: 6),
            const Text(
              'These products can no longer be returned to the supplier. They are potential losses.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ...closed.map((p) => _returnWindowCard(p)),
            const SizedBox(height: 20),
          ],

          if (returnable.isNotEmpty) ...[
            _sectionLabel('✓ RETURNABLE', Colors.green),
            const SizedBox(height: 6),
            const Text(
              'These products are still within the 6-month return window.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ...returnable.map((p) => _returnWindowCard(p)),
            const SizedBox(height: 20),
          ],

          if (_returnableProducts.isEmpty && closed.isEmpty && closedSoon.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56, color: Colors.green[300]),
                    const SizedBox(height: 12),
                    const Text('No return issues',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text('All products are within the return window.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Text(label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.8));
  }

  Widget _returnStatCard(
      String count, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(count,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _returnWindowCard(Product product) {
    final ws = product.returnWindowStatus;
    final color = _windowStatusColor(ws);

    String deadlineText;
    if (ws == ReturnWindowStatus.windowClosed) {
      deadlineText =
          'Deadline was ${DateFormat('MMM d, yyyy').format(product.returnDeadline)} '
          '(${-product.daysUntilReturnDeadline}d ago)';
    } else if (ws == ReturnWindowStatus.expired) {
      deadlineText = 'Product expired';
    } else {
      deadlineText =
          'Return by ${DateFormat('MMM d, yyyy').format(product.returnDeadline)} '
          '(${product.daysUntilReturnDeadline}d left)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showProductDetails(product),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.genericName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    if (product.brandName.isNotEmpty)
                      Text(product.brandName,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic)),
                    const SizedBox(height: 3),
                    Text(product.supplierName,
                        style: const TextStyle(fontSize: 11)),
                    Text(deadlineText,
                        style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_windowStatusLabel(ws),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ),
                  if (product.isReturnable &&
                      product.returnStatus != ReturnStatus.pending) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _markReturnInitiated(product),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: const Text('Mark Return',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange)),
                      ),
                    ),
                  ] else if (product.returnStatus == ReturnStatus.pending) ...[
                    const SizedBox(height: 6),
                    const Text('Pending return',
                        style: TextStyle(fontSize: 10, color: Colors.orange)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Medicines Tab ────────────────────────────────────────────────────────

  Widget _buildMedicinesTab() {
    if (_invoicesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final medicines = _sortedMedicines;
    final expiredCount = medicines.where((r) => r.isExpired).length;
    final soonCount =
        medicines.where((r) => r.isExpiringSoon && !r.isExpired).length;

    return RefreshIndicator(
      onRefresh: () async => _listenToInvoices(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary cards ──
          Row(children: [
            Expanded(
                child: _medStatCard(
                    '${medicines.length}', 'Total', Icons.medication,
                    const Color(0xFF0D47A1))),
            const SizedBox(width: 8),
            Expanded(
                child: _medStatCard(
                    '$soonCount', 'Expiring Soon', Icons.timer_outlined,
                    Colors.orange)),
            const SizedBox(width: 8),
            Expanded(
                child: _medStatCard(
                    '$expiredCount', 'Expired', Icons.warning_amber,
                    Colors.red)),
          ]),
          const SizedBox(height: 14),

          // ── Search ──
          TextField(
            decoration: InputDecoration(
              hintText: 'Search medicine, supplier, batch...',
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF0D47A1)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF0D47A1), width: 1)),
            ),
            onChanged: (v) => setState(() => _medicineSearch = v),
          ),
          const SizedBox(height: 12),

          if (medicines.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.medication, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No medicines found',
                        style:
                            TextStyle(fontSize: 16, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Text('Tap Check In to scan an invoice',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
            )
          else
            ...medicines.map((r) => _buildMedicineCard(r)),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _medStatCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(InvoiceRecord record) {
    Color expiryColor;
    String expiryLabel;

    if (record.isExpired) {
      expiryColor = Colors.red;
      expiryLabel = 'EXPIRED';
    } else if (record.isExpiringSoon) {
      expiryColor = Colors.orange;
      final days = record.parsedExpiry.difference(DateTime.now()).inDays;
      expiryLabel = 'Exp. in ${days}d';
    } else {
      expiryColor = Colors.green;
      expiryLabel = 'OK';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Slidable(
          key: ValueKey(record.id),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.5,
            children: [
              SlidableAction(
                onPressed: (_) => _showEditItemSheet(record),
                icon: Icons.edit,
                label: 'Edit',
                backgroundColor: const Color(0xFF0D47A1),
              ),
              SlidableAction(
                onPressed: (_) => _deleteInvoiceItem(record),
                icon: Icons.delete,
                label: 'Delete',
                backgroundColor: Colors.red,
              ),
            ],
          ),
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showEditItemSheet(record),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left color bar
                    Container(
                      width: 4,
                      height: 64,
                      decoration: BoxDecoration(
                          color: expiryColor,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.description.isNotEmpty
                                ? record.description
                                : '(no description)',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            record.supplierName.isNotEmpty
                                ? record.supplierName
                                : 'Unknown supplier',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 5,
                            runSpacing: 3,
                            children: [
                              if (record.quantity.isNotEmpty)
                                _chip('Qty: ${record.quantity}',
                                    const Color(0xFF0D47A1)),
                              if (record.batchNo.isNotEmpty)
                                _chip('Batch: ${record.batchNo}',
                                    Colors.purple),
                              if (record.invoiceNumber.isNotEmpty)
                                _chip('Inv: ${record.invoiceNumber}',
                                    Colors.grey),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Expiry badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: expiryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(expiryLabel,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: expiryColor)),
                        ),
                        const SizedBox(height: 4),
                        // Expiry date
                        Text(
                          record.expiryDate.isNotEmpty
                              ? record.expiryDate
                              : 'No expiry',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
                        // Amount
                        if (record.amount.isNotEmpty)
                          Text(
                            '₱${record.amount}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Invoices Tab ─────────────────────────────────────────────────────────

  Widget _buildInvoicesTab() {
    if (_invoicesLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final grouped = _groupedInvoices;

    return RefreshIndicator(
      onRefresh: () async => _listenToInvoices(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
                child: _invoiceStatCard('${grouped.length}', 'Invoices',
                    Icons.receipt_long, const Color(0xFF0D47A1))),
            const SizedBox(width: 10),
            Expanded(
                child: _invoiceStatCard(
                    '₱${NumberFormat('#,##0').format(_totalInvoiceSpend)}',
                    'Total Spend',
                    Icons.payments,
                    Colors.green[700]!)),
          ]),
          const SizedBox(height: 14),

          TextField(
            decoration: InputDecoration(
              hintText: 'Search supplier or invoice number...',
              prefixIcon:
                  const Icon(Icons.search, color: Color(0xFF0D47A1)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF0D47A1), width: 1)),
            ),
            onChanged: (v) => setState(() => _invoiceSearch = v),
          ),
          const SizedBox(height: 12),

          if (grouped.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long,
                        size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No invoices yet',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    Text('Tap Check In to scan your first invoice',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400])),
                  ],
                ),
              ),
            )
          else
            ...grouped.map((g) => _buildInvoiceGroupCard(g)),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _invoiceStatCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color)),
              Text(label,
                  style:
                      TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceGroupCard(GroupedInvoice group) {
    final dateLabel = group.scannedAt != null
        ? DateFormat('MMM d, yyyy').format(group.scannedAt!)
        : group.deliveryDate;

    final totalAmount = group.invoiceTotal.isNotEmpty
        ? '₱${group.invoiceTotal}'
        : '₱${group.items.fold(0.0, (s, i) => s + (double.tryParse(i.amount) ?? 0)).toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long,
                color: Color(0xFF0D47A1), size: 18),
          ),
          title: Text(
            group.supplierName.isNotEmpty
                ? group.supplierName
                : 'Unknown Supplier',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1)),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.invoiceNumber.isNotEmpty)
                Text(group.invoiceNumber,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(dateLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(totalAmount,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1))),
                  Text('${group.items.length} items',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _deleteInvoiceGroup(group),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 15),
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1, indent: 14, endIndent: 14),
            ...group.items.map((item) => _buildInvoiceItemTile(item)),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItemTile(InvoiceRecord item) {
    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => _showEditItemSheet(item),
            icon: Icons.edit,
            label: 'Edit',
            backgroundColor: const Color(0xFF0D47A1),
          ),
          SlidableAction(
            onPressed: (_) => _deleteInvoiceItem(item),
            icon: Icons.delete,
            label: 'Delete',
            backgroundColor: Colors.red,
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showEditItemSheet(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medication,
                    color: Color(0xFF0D47A1), size: 13),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description.isNotEmpty
                          ? item.description
                          : '(no description)',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        if (item.itemCode.isNotEmpty)
                          _chip(item.itemCode, Colors.grey),
                        if (item.quantity.isNotEmpty)
                          _chip(item.quantity, const Color(0xFF0D47A1)),
                        if (item.batchNo.isNotEmpty)
                          _chip('Batch: ${item.batchNo}', Colors.orange),
                        if (item.expiryDate.isNotEmpty)
                          _chip('Exp: ${item.expiryDate}', Colors.red),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (item.amount.isNotEmpty)
                Text('₱${item.amount}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, color: color, fontWeight: FontWeight.w500)),
    );
  }

  // ─── Shared widgets ───────────────────────────────────────────────────────

  Widget _sheetField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          filled: true,
          fillColor: const Color(0xFFF8F9FF),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D47A1))),
        ),
      ),
    );
  }
}

// ─── Pinned TabBar delegate ───────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: Colors.white, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}