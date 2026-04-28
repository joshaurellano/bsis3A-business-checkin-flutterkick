import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_checkin_screen.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';

import 'dart:async';

class PharmaDashboard extends StatefulWidget {
  const PharmaDashboard({super.key});

  @override
  State<PharmaDashboard> createState() => _PharmaDashboardState();
}

class _PharmaDashboardState extends State<PharmaDashboard> {
  StreamSubscription? _productSubscription;
  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;
  List<Product> products = [];
  List<TransferOrder> transfers = [];
  final List<String> branches = const [
    'Main Branch',
    'Centro',
    'San Felipe',
    'Cararayan',
    'Botika Penafrancia',
  ];
  bool _isLoading = true;
  String selectedBranch = 'Main Branch';
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _listenToProducts();
    _loadTransfers();
  }

  void _listenToProducts() {
    _productSubscription?.cancel();
    _productSubscription = _firestoreService.getProducts().listen((data) {
      setState(() {
        products = data;
        _isLoading = false;
      });
    }, onError: (error) {
      setState(() => _isLoading = false);
      debugPrint('Firestore error: $error');
    });
  }

  void _loadTransfers() {
    transfers = TransferOrder.generateMockData();
  }

  @override
  void dispose() {
    _productSubscription?.cancel();
    super.dispose();
  }

  List<Product> get filteredProducts {
    if (searchQuery.isEmpty) return products;
    return products.where((p) =>
      p.genericName.toLowerCase().contains(searchQuery.toLowerCase()) ||
      p.brandName.toLowerCase().contains(searchQuery.toLowerCase()) ||
      p.supplierName.toLowerCase().contains(searchQuery.toLowerCase()) ||
      p.dosageForm.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  void _onSearchChanged(String value) {
    setState(() => searchQuery = value);
  }

  // ─── Status Helpers ───────────────────────────────────────────────────────

  Color _getStatusColor(Product product) {
    switch (product.stockStatus) {
      case 'Expired': return Colors.red;
      case 'Near Expiry': return Colors.orange;
      default: return Colors.green;
    }
  }

  int _getExpiringCount() {
    return products.where((p) =>
      p.stockStatus == 'Near Expiry' || p.stockStatus == 'Expired'
    ).length;
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _listenToProducts(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Header ──
                  SliverToBoxAdapter(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0D47A1),
                            Color(0xFF1976D2),
                            Color(0xFF2196F3),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Welcome,',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          user?.displayName ?? user?.email ?? 'User',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.notifications_none, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_getExpiringCount()}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Main Content ──
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                        // OPERATIONS
                        const Text(
                          'OPERATIONS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildQuickActionsGrid(),
                        const SizedBox(height: 24),

                        // Expiry Alert
                        _buildExpiryAlertSection(),
                        const SizedBox(height: 24),

                        // INVENTORY header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'INVENTORY',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            TextButton(
                              onPressed: _navigateToAddCheckIn,
                              child: const Text('+ Add New'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildQuickInventoryAccess(),
                        const SizedBox(height: 16),

                        // Search Bar
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by generic name, brand, supplier...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF2196F3)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2196F3)),
                              onPressed: _startScanner,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Color(0xFF2196F3), width: 1),
                            ),
                          ),
                          onChanged: _onSearchChanged,
                        ),
                        const SizedBox(height: 16),

                        // Products List
                        if (filteredProducts.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('No check-ins found'),
                            ),
                          )
                        else
                          ...filteredProducts.map((p) => _buildProductCard(p)),
                        const SizedBox(height: 16),

                        // Transfer Section
                        _buildTransferSection(),
                        const SizedBox(height: 80),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddCheckIn,
        backgroundColor: const Color(0xFF0D47A1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Check In', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ─── Quick Actions ────────────────────────────────────────────────────────

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildActionCard(
          'Product\nInventory',
          Icons.inventory,
          const Color(0xFF2196F3),
          _showInventory,
        ),
        _buildActionCard(
          'Return to\nSupplier',
          Icons.assignment_return,
          const Color(0xFF9C27B0),
          _showReturnManagement,
        ),
        _buildActionCard(
          'Transfer\n${transfers.length} Open',
          Icons.swap_horiz,
          const Color(0xFFFF9800),
          _showTransferManagement,
        ),
        _buildActionCard(
          'Expiry Alert\n${_getExpiringCount()} items',
          Icons.warning_amber,
          const Color(0xFFF44336),
          _showExpiryAlert,
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Quick Inventory Access ───────────────────────────────────────────────

  Widget _buildQuickInventoryAccess() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: [
        _buildInventoryQuickLink('OK Stock >', Icons.check_circle, Colors.green, _filterByAvailability),
        _buildInventoryQuickLink('Near Expiry >', Icons.timer, Colors.orange, _filterByExpiry),
        _buildInventoryQuickLink('Add Check-In >', Icons.add_circle, Colors.blue, _navigateToAddCheckIn),
        _buildInventoryQuickLink('Item Locator >', Icons.location_on, Colors.purple, _showItemLocator),
      ],
    );
  }

  Widget _buildInventoryQuickLink(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Expiry Alert Section ─────────────────────────────────────────────────

  Widget _buildExpiryAlertSection() {
    final expiringProducts = products.where((p) =>
      p.stockStatus == 'Near Expiry' || p.stockStatus == 'Expired'
    ).toList();

    if (expiringProducts.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Color(0xFFE65100)),
                const SizedBox(width: 8),
                const Text(
                  'Expiry Alerts',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                const Spacer(),
                Text(
                  '${expiringProducts.length} items',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: expiringProducts.take(5).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final product = expiringProducts[index];
                  final isExpired = product.stockStatus == 'Expired';
                  return Container(
                    width: 160,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isExpired
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.genericName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.brandName,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? Colors.red.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.stockStatus,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isExpired ? Colors.red : Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Exp: ${product.expiryDate}',
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Product Card ─────────────────────────────────────────────────────────

  Widget _buildProductCard(Product product) {
    final statusColor = _getStatusColor(product);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(Icons.medication, color: statusColor),
        ),
        title: Text(
          product.genericName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brandName.isNotEmpty)
              Text(
                product.brandName,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            Text(
              'Supplier: ${product.supplierName}',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              '${product.dosageForm}  •  Exp: ${product.expiryDate}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                product.stockStatus,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            if (product.sellingPrice.isNotEmpty && product.sellingPrice != '0.00')
              Text(
                '₱${product.sellingPrice}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
          ],
        ),
        onTap: () => _showProductDetails(product),
      ),
    );
  }

  // ─── Product Details ──────────────────────────────────────────────────────

  void _showProductDetails(Product product) {
    final statusColor = _getStatusColor(product);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.genericName,
              style: const TextStyle(color: Color(0xFF0D47A1), fontSize: 16),
            ),
            if (product.brandName.isNotEmpty)
              Text(
                product.brandName,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Supplier', product.supplierName),
              _buildDetailRow('Dosage Form', product.dosageForm),
              _buildDetailRow('Selling Price',
                product.sellingPrice.isNotEmpty && product.sellingPrice != '0.00'
                    ? '₱${product.sellingPrice}'
                    : 'Not set',
              ),
              _buildDetailRow('Expiry Date', product.expiryDate),
              _buildDetailRow('Stock Status', product.stockStatus,
                  valueColor: statusColor),
              if (product.note.isNotEmpty)
                _buildDetailRow('Note', product.note),
              _buildDetailRow('Proof Label', product.proofLabel),
              if (product.createdAt != null)
                _buildDetailRow(
                  'Logged On',
                  DateFormat('MMM dd, yyyy – hh:mm a').format(product.createdAt!),
                ),
              if (product.lat != null && product.lng != null)
                _buildDetailRow(
                  'Location',
                  'lat: ${product.lat!.toStringAsFixed(5)}  •  lng: ${product.lng!.toStringAsFixed(5)}',
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transfer Section ─────────────────────────────────────────────────────

  Widget _buildTransferSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz, color: Color(0xFFFF9800)),
                SizedBox(width: 8),
                Text(
                  'TRANSFER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedBranch,
              decoration: const InputDecoration(
                labelText: 'Select Target Branch',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixIcon: Icon(Icons.location_on, color: Color(0xFFFF9800)),
              ),
              items: branches.map((branch) => DropdownMenuItem(
                value: branch,
                child: Text(branch),
              )).toList(),
              onChanged: (value) {
                if (value != null) setState(() => selectedBranch = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Product>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Product to Transfer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixIcon: Icon(Icons.medication, color: Color(0xFFFF9800)),
              ),
              items: products.map((product) => DropdownMenuItem(
                value: product,
                child: Text(
                  '${product.genericName} (${product.brandName})',
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: (product) {
                if (product != null) _showTransferDialog(product);
              },
            ),
            const SizedBox(height: 12),
            if (transfers.isNotEmpty) ...[
              const Text(
                'Recent Transfers:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              ...transfers.take(2).map((transfer) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle, size: 16, color: Colors.green),
                title: Text(transfer.productName, style: const TextStyle(fontSize: 13)),
                subtitle: Text(
                  'To: ${transfer.toBranch} • ${transfer.quantity} units',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  DateFormat('MMM dd').format(transfer.date),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Transfer Dialog ──────────────────────────────────────────────────────

  void _showTransferDialog(Product product) {
    final quantityController = TextEditingController(text: '1');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Transfer Product',
            style: TextStyle(color: Color(0xFFFF9800))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generic: ${product.genericName}'),
            if (product.brandName.isNotEmpty)
              Text('Brand: ${product.brandName}'),
            Text('Supplier: ${product.supplierName}'),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to transfer',
                border: OutlineInputBorder(),
                suffixText: 'units',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            Text('To: $selectedBranch'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0) {
                final newTransfer = TransferOrder(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  productId: product.id,
                  productName: product.genericName,
                  quantity: quantity,
                  fromBranch: 'Main Branch',
                  toBranch: selectedBranch,
                  date: DateTime.now(),
                  status: 'Pending',
                );
                setState(() => transfers.insert(0, newTransfer));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transfer request submitted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid quantity'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9800)),
            child: const Text('Submit Transfer'),
          ),
        ],
      ),
    );
  }

  // ─── Scanner ──────────────────────────────────────────────────────────────

  void _startScanner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Scan Product',
            style: TextStyle(color: Color(0xFF0D47A1))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 100, color: Color(0xFF2196F3)),
            const SizedBox(height: 16),
            const Text('Point camera at product barcode'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Or enter barcode manually',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                Navigator.pop(context);
                _findProductByBarcode(value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _findProductByBarcode(String barcode) {
    final matches = products.where((p) =>
      p.id == barcode || p.proofLabel == barcode
    ).toList();
    if (matches.isNotEmpty) {
      _showProductDetails(matches.first);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No product found for that barcode'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Item Locator ─────────────────────────────────────────────────────────

  void _showItemLocator() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Item Locator',
            style: TextStyle(color: Color(0xFF0D47A1))),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select product to locate:'),
              const SizedBox(height: 12),
              ...products.map((product) => ListTile(
                dense: true,
                leading: const Icon(Icons.location_on, color: Colors.purple),
                title: Text(product.genericName),
                subtitle: Text(product.brandName),
                onTap: () {
                  Navigator.pop(context);
                  if (product.lat != null && product.lng != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${product.genericName} — lat: ${product.lat!.toStringAsFixed(5)}, lng: ${product.lng!.toStringAsFixed(5)}',
                        ),
                        backgroundColor: Colors.purple,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('No GPS location recorded for ${product.genericName}'),
                        backgroundColor: Colors.grey,
                      ),
                    );
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _navigateToAddCheckIn() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCheckInScreen()),
    );
  }

  void _showInventory() {}
  void _showReturnManagement() {}
  void _showTransferManagement() {}
  void _showExpiryAlert() {}
  void _filterByAvailability() {}
  void _filterByExpiry() {}
}

// ─── TransferOrder Model ──────────────────────────────────────────────────────

class TransferOrder {
  final String id;
  final String productId;
  final String productName;
  final int quantity;
  final String fromBranch;
  final String toBranch;
  final DateTime date;
  final String status;

  TransferOrder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.fromBranch,
    required this.toBranch,
    required this.date,
    required this.status,
  });

  static List<TransferOrder> generateMockData() {
    return [
      TransferOrder(
        id: '1',
        productId: 'PRD001',
        productName: 'Paracetamol',
        quantity: 50,
        fromBranch: 'Main Branch',
        toBranch: 'Centro',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Completed',
      ),
      TransferOrder(
        id: '2',
        productId: 'PRD002',
        productName: 'Amoxicillin',
        quantity: 30,
        fromBranch: 'Main Branch',
        toBranch: 'San Felipe',
        date: DateTime.now().subtract(const Duration(days: 5)),
        status: 'Completed',
      ),
      TransferOrder(
        id: '3',
        productId: 'PRD003',
        productName: 'Omeprazole',
        quantity: 10,
        fromBranch: 'Main Branch',
        toBranch: 'Cararayan',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Pending',
      ),
    ];
  }
}