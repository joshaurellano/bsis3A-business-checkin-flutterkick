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
    return products.where((product) =>
      product.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
      product.supplier.toLowerCase().contains(searchQuery.toLowerCase()) ||
      product.batchNumber.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  void _onSearchChanged(String value) {
    setState(() {
      searchQuery = value;
    });
  }

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
                  // Header Section with Gradient
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
                                          overflow: TextOverflow.ellipsis,   // add this too
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
                                    child: const Row(
                                      children: [
                                        Icon(Icons.notifications_none, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          '3',
                                          style: TextStyle(color: Colors.white),
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
                  
                  // Main Content
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // OPERATIONS Section
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
                        
                        // Expiry Alert Section
                        _buildExpiryAlertSection(),
                        const SizedBox(height: 24),
                        
                        // INVENTORY Section
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
                              onPressed: _showAddProductDialog,
                              child: const Text('View All >'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildQuickInventoryAccess(),
                        const SizedBox(height: 16),
                        
                        // Search Bar with Scanner
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search products...',
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF2196F3)),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF2196F3)),
                              onPressed: _startScanner,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              borderSide: const BorderSide(color: Color(0xFF2196F3), width: 1),
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
                              child: Text('No products found'),
                            ),
                          )
                        else
                          ...filteredProducts.map((product) => _buildProductCard(product)),
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
      // Floating Action Button for Scanner
      floatingActionButton: FloatingActionButton(
        onPressed: _startScanner,
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildActionCard('Product\ninventory', Icons.inventory, const Color(0xFF2196F3), _showInventory),
        _buildActionCard('Return to\nSupplier', Icons.assignment_return, const Color(0xFF9C27B0), _showReturnManagement),
        _buildActionCard('Transfer\n${transfers.length} Open Projects', Icons.swap_horiz, const Color(0xFFFF9800), _showTransferManagement),
        _buildActionCard('Expiry alert\n${_getExpiringCount()}', Icons.warning_amber, const Color(0xFFF44336), _showExpiryAlert),
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
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
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

  Widget _buildQuickInventoryAccess() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.5,
      children: <Widget>[
        _buildInventoryQuickLink('availability >', Icons.check_circle, Colors.green, _filterByAvailability),
        _buildInventoryQuickLink('expiry >', Icons.timer, Colors.orange, _filterByExpiry),
        _buildInventoryQuickLink('add product >', Icons.add_circle, Colors.blue, _showAddProductDialog),
        _buildInventoryQuickLink('item locator >', Icons.location_on, Colors.purple, _showItemLocator),
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
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
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

  Widget _buildExpiryAlertSection() {
    final List<Product> expiringProducts = products.where((p) => p.daysUntilExpiry <= 30 && p.daysUntilExpiry > 0).toList();
    
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
                  'Expiring Soon',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                const Spacer(),
                Text(
                  '${expiringProducts.length} items',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE65100),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: expiringProducts.take(3).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final product = expiringProducts[index];
                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${product.daysUntilExpiry} days left',
                          style: TextStyle(
                            fontSize: 10,
                            color: product.daysUntilExpiry <= 7 ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
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

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(product).withValues(alpha: 0.1),
          child: Icon(
            Icons.medication,
            color: _getStatusColor(product),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier: ${product.supplier}'),
            Text('Batch: ${product.batchNumber} • Stock: ${product.stock} units'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(product).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusText(product),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(product),
                ),
              ),
            ),
            if (product.daysUntilExpiry <= 30)
              Text(
                'Expires: ${DateFormat('MMM dd').format(product.expiryDate)}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        onTap: () => _showProductDetails(product),
      ),
    );
  }

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
              initialValue: selectedBranch,
              decoration: const InputDecoration(
                labelText: 'Select Target Branch',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                prefixIcon: Icon(Icons.location_on, color: Color(0xFFFF9800)),
              ),
              items: branches.map((branch) {
                return DropdownMenuItem<String>(
                  value: branch,
                  child: Text(branch),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedBranch = newValue;
                  });
                }
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
              items: products.where((p) => p.stock > 0).map((product) {
                return DropdownMenuItem<Product>(
                  value: product,
                  child: Text('${product.name} (${product.stock} units)'),
                );
              }).toList(),
              onChanged: (Product? product) {
                if (product != null) {
                  _showTransferDialog(product);
                }
              },
            ),
            const SizedBox(height: 12),
            if (transfers.isNotEmpty)
              const Text(
                'Recent Transfers:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ...transfers.take(2).map((transfer) => ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle, size: 16, color: Colors.green),
              title: Text(
                transfer.productName,
                style: const TextStyle(fontSize: 13),
              ),
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
        ),
      ),
    );
  }

  // Scanner Functionality
  void _startScanner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Scan Product', style: TextStyle(color: Color(0xFF0D47A1))),
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
    final product = products.firstWhere(
      (p) => p.id == barcode || p.batchNumber == barcode,
      orElse: () => products.first,
    );
    _showProductDetails(product);
  }

  // Item Locator
  void _showItemLocator() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Item Locator', style: TextStyle(color: Color(0xFF0D47A1))),
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
                title: Text(product.name),
                subtitle: Text('Location: Row ${product.id.hashCode % 10}, Shelf ${(product.id.hashCode ~/ 10) % 5}'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} is located at Row ${product.id.hashCode % 10}, Shelf ${(product.id.hashCode ~/ 10) % 5}'),
                      backgroundColor: Colors.purple,
                    ),
                  );
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  // Transfer Dialog
  void _showTransferDialog(Product product) {
    final quantityController = TextEditingController(text: '1');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Transfer Product', style: TextStyle(color: Color(0xFFFF9800))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Product: ${product.name}'),
            const SizedBox(height: 8),
            Text('Available: ${product.stock} units'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0 && quantity <= product.stock) {
                final newTransfer = TransferOrder(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  productId: product.id,
                  productName: product.name,
                  quantity: quantity,
                  fromBranch: 'Main Branch',
                  toBranch: selectedBranch,
                  date: DateTime.now(),
                  status: 'Pending',
                );
                setState(() {
                  transfers.insert(0, newTransfer);
                });
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

  // Product Details
  void _showProductDetails(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(product.name, style: const TextStyle(color: Color(0xFF0D47A1))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Supplier', product.supplier),
            _buildDetailRow('Batch Number', product.batchNumber),
            _buildDetailRow('Stock Quantity', '${product.stock} units'),
            _buildDetailRow('Purchase Price', '₱${product.purchasePrice.toStringAsFixed(2)}'),
            _buildDetailRow('Selling Price', '₱${product.sellingPrice.toStringAsFixed(2)}'),
            _buildDetailRow('Manufacture Date', DateFormat('MMM dd, yyyy').format(product.manufactureDate)),
            _buildDetailRow('Expiry Date', DateFormat('MMM dd, yyyy').format(product.expiryDate)),
            _buildDetailRow('Status', _getStatusText(product)),
          ],
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

  Widget _buildDetailRow(String label, String value) {
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
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Helper Methods
  int _getExpiringCount() {
    return products.where((p) => p.daysUntilExpiry <= 30 && p.daysUntilExpiry > 0).length;
  }

  Color _getStatusColor(Product product) {
    if (product.daysUntilExpiry <= 0) return Colors.red;
    if (product.daysUntilExpiry <= 30) return Colors.orange;
    return Colors.green;
  }

  String _getStatusText(Product product) {
    if (product.daysUntilExpiry <= 0) return 'Expired';
    if (product.daysUntilExpiry <= 30) return 'Expiring Soon';
    return 'Good';
  }

  // Placeholder Methods for Navigation
  static void _showInventory() {
    // Navigate to full inventory screen
  }
  
  static void _showReturnManagement() {
    // Navigate to return management screen
  }
  
  static void _showTransferManagement() {
    // Navigate to transfer management screen
  }
  
  static void _showExpiryAlert() {
    // Navigate to expiry alerts screen
  }
  
  static void _showAllInventory() {
    // Navigate to all inventory screen
  }
  
  static void _filterByAvailability() {
    // Filter products by availability
  }
  
  static void _filterByExpiry() {
    // Filter products by expiry date
  }
  
  void _showAddProductDialog() {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const AddCheckInScreen()),
  );
}

}

// Data Models
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
        productName: 'Paracetamol 500mg',
        quantity: 50,
        fromBranch: 'Main Branch',
        toBranch: 'North Branch - Quezon City',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Completed',
      ),
      TransferOrder(
        id: '2',
        productId: 'PRD002',
        productName: 'Amoxicillin 250mg',
        quantity: 30,
        fromBranch: 'Main Branch',
        toBranch: 'South Branch - Makati',
        date: DateTime.now().subtract(const Duration(days: 5)),
        status: 'Completed',
      ),
      TransferOrder(
        id: '3',
        productId: 'PRD005',
        productName: 'Insulin Injections',
        quantity: 10,
        fromBranch: 'Main Branch',
        toBranch: 'East Branch - Pasig',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Pending',
      ),
    ];
  }
}