import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/product_model.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final user = FirebaseAuth.instance.currentUser;

  late TextEditingController _genericNameController;
  late TextEditingController _brandNameController;
  late TextEditingController _supplierController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _expiryDateController;
  late TextEditingController _noteController;
  late String _selectedDosageForm;
  late String _selectedStockStatus;
  late String updatedBy;

  final List<String> _dosageForms = [
    'Tablet', 'Capsule', 'Syrup', 'Injection', 'Cream', 'Drops', 'Inhaler', 'Patch', 'Other',
  ];

  final List<String> _stockStatuses = ['Available', 'Near Expiry', 'Expired'];

  @override
  void initState() {
    super.initState();
    _genericNameController  = TextEditingController(text: widget.product.genericName);
    _brandNameController    = TextEditingController(text: widget.product.brandName);
    _supplierController     = TextEditingController(text: widget.product.supplierName);
    _sellingPriceController = TextEditingController(text: widget.product.sellingPrice);
    _expiryDateController   = TextEditingController(text: widget.product.expiryDate);
    _noteController         = TextEditingController(text: widget.product.note);
    _selectedDosageForm     = _dosageForms.contains(widget.product.dosageForm)
        ? widget.product.dosageForm
        : 'Other';
    _selectedStockStatus    = _stockStatuses.contains(widget.product.stockStatus)
        ? widget.product.stockStatus
        : 'Available';
  }

  @override
  void dispose() {
    _genericNameController.dispose();
    _brandNameController.dispose();
    _supplierController.dispose();
    _sellingPriceController.dispose();
    _expiryDateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      filled: true,
      fillColor: Colors.white,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFF2196F3), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              widget.product.genericName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
                  final updatedProduct = Product(
                    id: widget.product.id,
                    genericName: _genericNameController.text.trim(),
                    brandName: _brandNameController.text.trim(),
                    supplierName: _supplierController.text.trim(),
                    sellingPrice: _sellingPriceController.text.trim(),
                    expiryDate: _expiryDateController.text.trim(),
                    note: _noteController.text.trim(),
                    dosageForm: _selectedDosageForm,
                    stockStatus: _selectedStockStatus,
                    proofLabel: widget.product.proofLabel,
                    createdBy: widget.product.createdBy,
                    createdAt: widget.product.createdAt,
                    updatedBy: user?.uid,
                    lat: widget.product.lat,
                    lng: widget.product.lng,
                  );
                  _firestoreService.updateProduct(updatedProduct);
                  Navigator.pop(context);
            },
            icon: const Icon(Icons.check, color: Colors.white, size: 18),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Basic Info ──
            _buildSectionHeader('Basic Information', Icons.info_outline, const Color(0xFF2196F3)),
            const SizedBox(height: 12),
            TextField(
              controller: _genericNameController,
              decoration: _fieldDecoration('Generic Name *', Icons.medication),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brandNameController,
              decoration: _fieldDecoration('Brand Name', Icons.label_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _supplierController,
              decoration: _fieldDecoration('Supplier Name *', Icons.business_outlined),
            ),
            const SizedBox(height: 24),

            // ── Product Details ──
            _buildSectionHeader('Product Details', Icons.description_outlined, const Color(0xFF9C27B0)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedDosageForm,
              decoration: _fieldDecoration('Dosage Form', Icons.science_outlined),
              items: _dosageForms.map((form) => DropdownMenuItem(
                value: form,
                child: Text(form),
              )).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedDosageForm = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sellingPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _fieldDecoration('Selling Price (₱)', Icons.payments_outlined),
            ),
            const SizedBox(height: 24),

            // ── Expiry & Status ──
            _buildSectionHeader('Expiry & Status', Icons.event_outlined, const Color(0xFFFF9800)),
            const SizedBox(height: 12),
            TextField(
              controller: _expiryDateController,
              readOnly: true,
              decoration: _fieldDecoration('Expiry Date', Icons.calendar_today_outlined).copyWith(
                suffixIcon: const Icon(Icons.edit_calendar, color: Color(0xFF2196F3)),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  _expiryDateController.text = DateFormat('MM/dd/yyyy').format(picked);
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedStockStatus,
              decoration: _fieldDecoration('Stock Status', Icons.inventory_2_outlined),
              items: _stockStatuses.map((status) {
                final color = status == 'Expired'
                    ? Colors.red
                    : status == 'Near Expiry'
                        ? Colors.orange
                        : Colors.green;
                return DropdownMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(status),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedStockStatus = value);
              },
            ),
            const SizedBox(height: 24),

            // ── Notes ──
            _buildSectionHeader('Additional Notes', Icons.notes_outlined, Colors.teal),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: _fieldDecoration('Note (optional)', Icons.edit_note).copyWith(
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),

            // ── Save Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final updatedProduct = Product(
                    id: widget.product.id,
                    genericName: _genericNameController.text.trim(),
                    brandName: _brandNameController.text.trim(),
                    supplierName: _supplierController.text.trim(),
                    sellingPrice: _sellingPriceController.text.trim(),
                    expiryDate: _expiryDateController.text.trim(),
                    note: _noteController.text.trim(),
                    dosageForm: _selectedDosageForm,
                    stockStatus: _selectedStockStatus,
                    proofLabel: widget.product.proofLabel,
                    createdBy: widget.product.createdBy,
                    createdAt: widget.product.createdAt,
                    updatedBy: user?.uid,
                    lat: widget.product.lat,
                    lng: widget.product.lng,
                  );
                  _firestoreService.updateProduct(updatedProduct);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.save_outlined, color: Colors.white),
                label: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
      ],
    );
  }
}