// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_checkin_screen.dart';
import '../models/product_model.dart';
import '../models/invoice_record.dart';
import '../services/firestore_service.dart';
import './analytics_screen.dart';

import 'dart:async';

// ─── Invoice Item Model ───────────────────────────────────────────────────────

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

  // ─── Supplier spend (for analytics) ──────────────────────────────────────

  Map<String, double> get _supplierSpend {
    final map = <String, double>{};
    for (final r in _allInvoiceRecords) {
      final spend = double.tryParse(r.amount) ?? 0;
      map[r.supplierName] = (map[r.supplierName] ?? 0) + spend;
    }
    return map;
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
      .where((p) => p.isReturnable && p.returnStatus != ReturnStatus.completed)
      .toList()
    ..sort((a, b) =>
        a.daysUntilReturnDeadline.compareTo(b.daysUntilReturnDeadline));

  int get _urgentReturnCount =>
      _returnSoonProducts.length + _windowClosedProducts.length;

  // ─── Product helpers ──────────────────────────────────────────────────────

  List<Product> get filteredProducts {
    final q = _productSearch.toLowerCase();
    if (q.isEmpty) return products;
    return products
        .where((p) =>
            p.genericName.toLowerCase().contains(q) ||
            p.brandName.toLowerCase().contains(q) ||
            p.supplierName.toLowerCase().contains(q))
        .toList();
  }

  Color _windowStatusColor(ReturnWindowStatus s) {
    switch (s) {
      case ReturnWindowStatus.returnable:
        return Colors.green;
      case ReturnWindowStatus.returnSoon:
        return Colors.orange;
      case ReturnWindowStatus.windowClosed:
        return Colors.red;
      case ReturnWindowStatus.expired:
        return Colors.grey;
    }
  }

  String _windowStatusLabel(ReturnWindowStatus s) {
    switch (s) {
      case ReturnWindowStatus.returnable:
        return 'Returnable';
      case ReturnWindowStatus.returnSoon:
        return 'Return Soon';
      case ReturnWindowStatus.windowClosed:
        return 'Window Closed';
      case ReturnWindowStatus.expired:
        return 'Expired';
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

  // Opens edit sheet (swipe action)
  void _showEditItemSheet(InvoiceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _EditItemSheet(
        record: record,
        onSaved: () => _showSnack('Medicine updated.'),
      ),
    );
  }

  // Opens detail + return sheet (tap action)
  void _showMedicineDetails(InvoiceRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MedicineDetailSheet(
        record: record,
        onReturned: () => _showSnack('Return recorded successfully.'),
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
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.assignment_return, size: 15),
                              const SizedBox(width: 5),
                              const Text('Returns',
                                  style: TextStyle(fontSize: 12)),
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
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long, size: 15),
                              const SizedBox(width: 5),
                              const Text('Invoices',
                                  style: TextStyle(fontSize: 12)),
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
      floatingActionButton: Semantics(
        label: 'Scan a new invoice',
        button: true,
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddCheckInScreen())),
          backgroundColor: const Color(0xFF0D47A1),
          icon: const Icon(Icons.add, color: Colors.white),
          label:
              const Text('Scan Invoice', style: TextStyle(color: Colors.white)),
        ),
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
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
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
                  // Analytics button
                  Semantics(
                    label: 'View analytics',
                    button: true,
                    child: IconButton(
                      icon: const Icon(Icons.bar_chart, color: Colors.white),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalyticsScreen(
                            totalMedicines: _allInvoiceRecords.length,
                            expiredCount: _expiredMedicineCount,
                            expiringSoonCount: _expiringSoonMedicineCount,
                            okCount: _allInvoiceRecords.length -
                                _expiredMedicineCount -
                                _expiringSoonMedicineCount,
                            supplierSpend: _supplierSpend,
                          ),
                        ),
                      ),
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
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
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
    final soonCount =
        medicines.where((r) => r.isExpiringSoon && !r.isExpired).length;

    return RefreshIndicator(
      onRefresh: () async => _listenToInvoices(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    Text('Tap Scan Invoice to get started',
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

  Widget _medStatCard(String value, String label, IconData icon, Color color) {
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
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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
              // TAP = detail + return sheet
              onTap: () => _showMedicineDetails(record),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                        Text(
                          record.expiryDate.isNotEmpty
                              ? record.expiryDate
                              : 'No expiry',
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 4),
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

  // ─── Returns Tab ──────────────────────────────────────────────────────────

  Widget _buildReturnsTab() {
    final expired = _allInvoiceRecords.where((r) => r.isExpired).toList();
    final expiringSoon = _allInvoiceRecords
        .where((r) => r.isExpiringSoon && !r.isExpired)
        .toList();

    return RefreshIndicator(
      onRefresh: () async => _listenToInvoices(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary cards ──
          Row(children: [
            Expanded(
                child: _returnStatCard('${expired.length}', 'Expired',
                    Colors.red, Icons.warning_amber)),
            const SizedBox(width: 10),
            Expanded(
                child: _returnStatCard('${expiringSoon.length}', 'Expiring Soon',
                    Colors.orange, Icons.timer_outlined)),
          ]),
          const SizedBox(height: 20),

          // ── Expired ──
          if (expired.isNotEmpty) ...[
            _sectionLabel('✕ EXPIRED — RETURN TO SUPPLIER', Colors.red),
            const SizedBox(height: 6),
            const Text(
              'These medicines have already expired and should be returned.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ...expired.map((r) => _returnCandidateCard(r, Colors.red)),
            const SizedBox(height: 20),
          ],

          // ── Expiring Soon ──
          if (expiringSoon.isNotEmpty) ...[
            _sectionLabel('⚠ EXPIRING SOON', Colors.orange),
            const SizedBox(height: 6),
            const Text(
              'These medicines expire within 6 months. Consider returning them.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            ...expiringSoon.map((r) => _returnCandidateCard(r, Colors.orange)),
            const SizedBox(height: 20),
          ],

          if (expired.isEmpty && expiringSoon.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 56, color: Colors.green[300]),
                    const SizedBox(height: 12),
                    const Text('No return candidates',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text('All medicines are within expiry.',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // ── Return History ──
          _sectionLabel('RETURN HISTORY', const Color(0xFF0D47A1)),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('return_logs')
                .orderBy('returnedAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.history, size: 40, color: Colors.grey),
                      SizedBox(height: 8),
                      Text('No returns recorded yet.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }
              return Column(
                children: docs.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final returnedAt = d['returnedAt'] is Timestamp
                      ? (d['returnedAt'] as Timestamp).toDate()
                      : null;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 60,
                          decoration: BoxDecoration(
                              color: const Color(0xFF0D47A1),
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['description']?.toString() ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                d['supplierName']?.toString() ?? '',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 5,
                                runSpacing: 3,
                                children: [
                                  _chip(
                                      'Returned: ${d['returnedQty']} ${d['unit'] ?? ''}',
                                      Colors.red),
                                  if ((d['batchNo'] ?? '').toString().isNotEmpty)
                                    _chip('Batch: ${d['batchNo']}',
                                        Colors.purple),
                                  if ((d['reason'] ?? '').toString().isNotEmpty)
                                    _chip(d['reason'].toString(), Colors.grey),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (returnedAt != null)
                          Text(
                            DateFormat('MMM d\nyyyy').format(returnedAt),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[400]),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _returnCandidateCard(InvoiceRecord record, Color color) {
    final days = record.parsedExpiry.difference(DateTime.now()).inDays;
    final label = record.isExpired
        ? 'Expired ${(-days)}d ago'
        : 'Expires in ${days}d';

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
        onTap: () => _showMedicineDetails(record),
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
                    Text(
                      record.description.isNotEmpty
                          ? record.description
                          : '(no description)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    if (record.supplierName.isNotEmpty)
                      Text(record.supplierName,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        if (record.quantity.isNotEmpty)
                          _chip('Qty: ${record.quantity}',
                              const Color(0xFF0D47A1)),
                        if (record.batchNo.isNotEmpty)
                          _chip('Batch: ${record.batchNo}', Colors.purple),
                        _chip(record.expiryDate, Colors.grey),
                      ],
                    ),
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
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _showMedicineDetails(record),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: const Text('Return',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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

  void _showProductDetails(Product product) async {
    final ws = product.returnWindowStatus;
    final wsColor = _windowStatusColor(ws);
    final creatorName = await _firestoreService.getUserName(product.createdBy);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  border:
                      Border.all(color: wsColor.withValues(alpha: 0.3)),
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
                _detailRow('Return Status',
                    product.returnStatus.name.toUpperCase()),
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
                    Text('Tap Scan Invoice to scan your first invoice',
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
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(dateLabel,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey[400])),
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
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[500])),
                ],
              ),
              const SizedBox(width: 4),
              Semantics(
                label: 'Delete invoice',
                button: true,
                child: GestureDetector(
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
        onTap: () => _showMedicineDetails(item),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFF0D47A1).withValues(alpha: 0.07),
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

// ─── Edit Item Sheet ──────────────────────────────────────────────────────────

class _EditItemSheet extends StatefulWidget {
  final InvoiceRecord record;
  final VoidCallback onSaved;

  const _EditItemSheet({required this.record, required this.onSaved});

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  late final TextEditingController _amount;
  late final TextEditingController _batchNo;
  late final TextEditingController _expiryDate;
  late final TextEditingController _itemCode;

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: widget.record.description);
    _quantity = TextEditingController(text: widget.record.quantity);
    _amount = TextEditingController(text: widget.record.amount);
    _batchNo = TextEditingController(text: widget.record.batchNo);
    _expiryDate = TextEditingController(text: widget.record.expiryDate);
    _itemCode = TextEditingController(text: widget.record.itemCode);
  }

  @override
  void dispose() {
    _description.dispose();
    _quantity.dispose();
    _amount.dispose();
    _batchNo.dispose();
    _expiryDate.dispose();
    _itemCode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance
        .collection('invoice_items')
        .doc(widget.record.id)
        .update({
      'description': _description.text,
      'quantity': _quantity.text,
      'amount': _amount.text,
      'batchNo': _batchNo.text,
      'expiryDate': _expiryDate.text,
      'itemCode': _itemCode.text,
    });
    if (mounted) {
      Navigator.pop(context);
      widget.onSaved();
    }
  }

  Widget _field(TextEditingController controller, String label) {
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
          focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Color(0xFF0D47A1))),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20),
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
              widget.record.invoiceNumber.isNotEmpty
                  ? 'Invoice: ${widget.record.invoiceNumber}'
                  : 'No invoice number',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            _field(_description, 'Description'),
            Row(children: [
              Expanded(child: _field(_quantity, 'Quantity')),
              const SizedBox(width: 8),
              Expanded(child: _field(_amount, 'Amount (₱)')),
            ]),
            Row(children: [
              Expanded(child: _field(_batchNo, 'Batch / Lot No.')),
              const SizedBox(width: 8),
              Expanded(child: _field(_expiryDate, 'Expiry Date')),
            ]),
            _field(_itemCode, 'Item Code'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
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
    );
  }
}

// ─── Medicine Detail + Return Sheet ──────────────────────────────────────────

class _MedicineDetailSheet extends StatefulWidget {
  final InvoiceRecord record;
  final VoidCallback onReturned;

  const _MedicineDetailSheet(
      {required this.record, required this.onReturned});

  @override
  State<_MedicineDetailSheet> createState() => _MedicineDetailSheetState();
}

class _MedicineDetailSheetState extends State<_MedicineDetailSheet> {
  bool _showReturnForm = false;
  final _returnQtyController = TextEditingController();
  final _returnReasonController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  // Extract the numeric part from strings like "10 BOX" or "5"
  int get _currentQty {
    final match = RegExp(r'\d+').firstMatch(widget.record.quantity);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  // Extract unit suffix like "BOX", "PCS" if present
  String get _qtyUnit {
    final raw = widget.record.quantity.trim();
    final match = RegExp(r'^\d+\s*(.*)$').firstMatch(raw);
    return match?.group(1)?.trim() ?? '';
  }

  @override
  void dispose() {
    _returnQtyController.dispose();
    _returnReasonController.dispose();
    super.dispose();
  }

  Future<void> _submitReturn() async {
    final returnQty = int.tryParse(_returnQtyController.text.trim());

    if (returnQty == null || returnQty <= 0) {
      setState(() => _error = 'Enter a valid quantity.');
      return;
    }
    if (returnQty > _currentQty) {
      setState(() => _error =
          'Cannot return more than current quantity ($_currentQty).');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final newQty = _currentQty - returnQty;
      final newQtyStr =
          _qtyUnit.isNotEmpty ? '$newQty $_qtyUnit' : '$newQty';

      final batch = FirebaseFirestore.instance.batch();

      // 1. Update the invoice item quantity
      batch.update(
        FirebaseFirestore.instance
            .collection('invoice_items')
            .doc(widget.record.id),
        {'quantity': newQtyStr},
      );

      // 2. Save a return log record
      final returnRef =
          FirebaseFirestore.instance.collection('return_logs').doc();
      batch.set(returnRef, {
        'id': returnRef.id,
        'invoiceItemId': widget.record.id,
        'description': widget.record.description,
        'supplierName': widget.record.supplierName,
        'invoiceNumber': widget.record.invoiceNumber,
        'batchNo': widget.record.batchNo,
        'expiryDate': widget.record.expiryDate,
        'returnedQty': returnQty,
        'remainingQty': newQty,
        'unit': _qtyUnit,
        'reason': _returnReasonController.text.trim(),
        'returnedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        widget.onReturned();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    Color expiryColor;
    String expiryLabel;
    if (record.isExpired) {
      expiryColor = Colors.red;
      expiryLabel = 'EXPIRED';
    } else if (record.isExpiringSoon) {
      expiryColor = Colors.orange;
      final days = record.parsedExpiry.difference(DateTime.now()).inDays;
      expiryLabel = 'Expiring in ${days}d';
    } else {
      expiryColor = Colors.green;
      expiryLabel = 'Good';
    }

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.description.isNotEmpty
                            ? record.description
                            : '(no description)',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1)),
                      ),
                      if (record.supplierName.isNotEmpty)
                        Text(record.supplierName,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: expiryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(expiryLabel,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: expiryColor)),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Details ──
            _detailRow(Icons.inventory_2_outlined, 'Current Quantity',
                record.quantity.isNotEmpty ? record.quantity : '—'),
            _detailRow(Icons.receipt_outlined, 'Invoice No.',
                record.invoiceNumber.isNotEmpty ? record.invoiceNumber : '—'),
            _detailRow(Icons.qr_code, 'Item Code',
                record.itemCode.isNotEmpty ? record.itemCode : '—'),
            _detailRow(Icons.batch_prediction_outlined, 'Batch / Lot',
                record.batchNo.isNotEmpty ? record.batchNo : '—'),
            _detailRow(Icons.event_outlined, 'Expiry Date',
                record.expiryDate.isNotEmpty ? record.expiryDate : '—'),
            if (record.amount.isNotEmpty)
              _detailRow(
                  Icons.payments_outlined, 'Amount', '₱${record.amount}'),

            const SizedBox(height: 20),

            // ── Return button (shows form when tapped) ──
            if (!_showReturnForm)
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _currentQty > 0
                      ? () => setState(() => _showReturnForm = true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.assignment_return, size: 18),
                  label: const Text('Return Items',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

            // ── Return form ──
            if (_showReturnForm) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Return Items',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                    const SizedBox(height: 4),
                    Text(
                      'Current quantity: $_currentQty${_qtyUnit.isNotEmpty ? ' $_qtyUnit' : ''}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),

                    // Quantity field
                    TextField(
                      controller: _returnQtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity to return',
                        hintText: 'Max $_currentQty',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.3))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.3))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.orange, width: 1.5)),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: 10),

                    // Reason field
                    TextField(
                      controller: _returnReasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason (optional)',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.3))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                                color:
                                    Colors.grey.withValues(alpha: 0.3))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Colors.orange, width: 1.5)),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 12)),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() {
                              _showReturnForm = false;
                              _error = null;
                              _returnQtyController.clear();
                              _returnReasonController.clear();
                            }),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                _isSaving ? null : _submitReturn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2))
                                : const Text('Confirm Return',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0D47A1)),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(label,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}