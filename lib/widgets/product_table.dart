import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';

class ProductTable extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onEdit;
  final Function(Product) onReturn;

  const ProductTable({
    super.key,
    required this.products,
    required this.onEdit,
    required this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inventory Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                // Implement search functionality
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey[100]),
                  columns: const [
                    DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: products.map((product) {
                    return DataRow(cells: [
                      DataCell(Text(product.name)),
                      DataCell(Text(product.batchNumber)),
                      DataCell(Text(product.supplier)),
                      DataCell(Text(product.stock.toString())),
                      DataCell(Text(DateFormat('MMM dd, yyyy').format(product.expiryDate))),
                      DataCell(_buildStatusChip(product)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => onEdit(product),
                            ),
                            if (product.eligibleForReturn)
                              IconButton(
                                icon: const Icon(Icons.assignment_return, size: 20),
                                onPressed: () => onReturn(product),
                              ),
                          ],
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(Product product) {
    Color color;
    String text;
    
    switch (product.status) {
      case ProductStatus.expired:
        color = Colors.red;
        text = 'Expired';
        break;
      case ProductStatus.expiringSoon:
        color = Colors.orange;
        text = 'Expiring Soon';
        break;
      case ProductStatus.good:
        color = Colors.green;
        text = 'Good';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}