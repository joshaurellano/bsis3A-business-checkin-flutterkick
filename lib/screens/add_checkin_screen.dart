import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final _veryfiClientId = dotenv.env['VERYFI_CLIENT_ID'] ?? '';
final _veryfiUsername = dotenv.env['VERYFI_USERNAME'] ?? '';
final _veryfiApiKey = dotenv.env['VERYFI_API_KEY'] ?? '';

// ─── Model ────────────────────────────────────────────────────────────────────

class InvoiceLineItem {
  String itemCode;
  String description;
  String quantity;
  String batchNo;
  String expiryDate;
  String amount;

  InvoiceLineItem({
    this.itemCode = '',
    this.description = '',
    this.quantity = '',
    this.batchNo = '',
    this.expiryDate = '',
    this.amount = '',
  });

  Map<String, dynamic> toMap() => {
        'itemCode': itemCode,
        'description': description,
        'quantity': quantity,
        'batchNo': batchNo,
        'expiryDate': expiryDate,
        'amount': amount,
      };
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class AddCheckInScreen extends StatefulWidget {
  const AddCheckInScreen({super.key});

  @override
  State<AddCheckInScreen> createState() => _AddCheckInScreenState();
}

class _AddCheckInScreenState extends State<AddCheckInScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // State
  File? _selectedImage;
  bool _isScanning = false;
  bool _isSaving = false;

  // Extracted invoice header
  String _supplierName = '';
  String _invoiceNumber = '';
  String _deliveryDate = '';

  // Extracted line items (editable)
  List<InvoiceLineItem> _items = [];

  // ─── OCR ──────────────────────────────────────────────────────────────────

Future<void> _scanInvoice(File imageFile) async {
  setState(() {
    _isScanning = true;
    _items = [];
    _supplierName = '';
    _invoiceNumber = '';
    _deliveryDate = '';
  });

  try {
    final imageBytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(imageBytes);
    final fileName = imageFile.path.split('/').last;

    final requestBody = jsonEncode({
      'file_data': base64Image,
      'file_name': fileName,
      'auto_delete': true,
      'boost_mode': 1,
    });

    final response = await http.post(
      Uri.parse('https://api.veryfi.com/api/v8/partner/documents/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'CLIENT-ID': _veryfiClientId,
        'AUTHORIZATION': 'apikey $_veryfiUsername:$_veryfiApiKey',
      },
      body: requestBody,
    );

    debugPrint('Veryfi status: ${response.statusCode}');
    debugPrint('Veryfi response: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 201) {
      _showSnack('API error ${response.statusCode}. Check credentials.', isError: true);
      return;
    }

    final data = jsonDecode(response.body);

    // ── Header fields ──
    _supplierName = data['vendor']?['name']?.toString() ?? '';
    _invoiceNumber = data['invoice_number']?.toString() ?? '';
    _deliveryDate = data['date']?.toString() ?? '';

    // ── Line items ──
    final rawItems = data['line_items'] as List<dynamic>? ?? [];

    final extractedItems = rawItems.map((item) {
      final qty = item['quantity']?.toString() ?? '';
      final unit = item['unit_of_measure']?.toString() ?? '';
      final fullQty = (unit.isNotEmpty && unit != 'null') ? '$qty $unit' : qty;

      final desc = item['description']?.toString() ?? '';
      final sku = item['sku']?.toString() ?? '';

      String expiry = item['expiry_date']?.toString() ?? '';
      if (expiry.isEmpty || expiry == 'null') {
        final expiryMatch = RegExp(
          r'(\d{4}[-\/]\d{2}[-\/]\d{2}|\d{2}[-\/]\d{4})',
        ).firstMatch(desc);
        expiry = expiryMatch?.group(1) ?? '';
      }

      String batch = item['lot_number']?.toString() ?? '';
      if (batch.isEmpty || batch == 'null') batch = '';

      final amount = item['total']?.toString() ?? item['price']?.toString() ?? '';

      return InvoiceLineItem(
        itemCode: (sku.isNotEmpty && sku != 'null') ? sku : '',
        description: desc,
        quantity: fullQty,
        batchNo: batch,
        expiryDate: expiry,
        amount: amount,
      );
    }).toList();

    setState(() => _items = extractedItems);

    if (_items.isEmpty) {
      _showSnack('No line items found. Fill in manually.', isError: true);
    } else {
      _showSnack('Detected ${_items.length} item(s). Review before saving.');
    }
  } catch (e) {
    debugPrint('Veryfi error: $e');
    _showSnack('Scan failed: $e', isError: true);
  } finally {
    setState(() => _isScanning = false);
  }
}
  // ─── Camera / Gallery ─────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final file = File(picked.path);
    setState(() => _selectedImage = file);
    await _scanInvoice(file);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0D47A1)),
              title: const Text('Take Photo of Invoice'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0D47A1)),
              title: const Text('Choose from Gallery'),
              onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }


  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_items.isEmpty) {
      _showSnack('No items to save.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('invoice_items');

      for (final item in _items) {
        final docRef = collection.doc();
        batch.set(docRef, {
          'id': docRef.id,
          'invoiceNumber': _invoiceNumber,
          'supplierName': _supplierName,
          'itemCode': item.itemCode,
          'description': item.description,
          'quantity': item.quantity,
          'batchNo': item.batchNo,
          'expiryDate': item.expiryDate,
          'amount': item.amount,
          'deliveryDate': _deliveryDate,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user?.uid ?? '',
        });
      }

      await batch.commit();
      _showSnack('${_items.length} item(s) saved successfully!');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Save error: $e');
      _showSnack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  void _addEmptyItem() {
    setState(() => _items.add(InvoiceLineItem()));
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Scan Invoice'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(_isSaving ? 'Saving…' : 'Save',
                  style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Step 1: Scan ──
            _sectionLabel('STEP 1 — SCAN INVOICE'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isScanning ? null : _showImageSourceSheet,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedImage != null
                        ? Colors.green
                        : const Color(0xFF0D47A1).withValues(alpha: 0.3),
                    width: _selectedImage != null ? 2 : 1,
                  ),
                ),
                child: _isScanning
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Reading invoice…', style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(_selectedImage!, fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              Text('Tap to scan invoice',
                                  style: TextStyle(color: Colors.grey[500])),
                              const SizedBox(height: 4),
                              
                            ],
                          ),
              ),
            ),
            if (_selectedImage != null && !_isScanning) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 4),
                  Text('Scanned', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                  const Spacer(),
                  TextButton(
                    onPressed: _showImageSourceSheet,
                    child: const Text('Rescan', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // ── Header Info ──
            if (_supplierName.isNotEmpty || _invoiceNumber.isNotEmpty) ...[
              _sectionLabel('DETECTED HEADER'),
              const SizedBox(height: 8),
              _headerInfoCard(),
              const SizedBox(height: 20),
            ],

            // ── Step 2: Review items ──
            Row(
              children: [
                _sectionLabel('STEP 2 — REVIEW ITEMS (${_items.length})'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addEmptyItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Row', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.inbox, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Scan an invoice or tap + Add Row.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else
              ..._items.asMap().entries.map((e) => _buildItemCard(e.key, e.value)),

            const SizedBox(height: 24),

            // ── Save button ──
            if (_items.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Saving…', style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : Text('Save ${_items.length} Item(s)',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _headerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _headerRow(Icons.business, 'Supplier', _supplierName),
            if (_invoiceNumber.isNotEmpty) ...[
              const Divider(height: 12),
              _headerRow(Icons.receipt, 'Invoice No.', _invoiceNumber),
            ],
            if (_deliveryDate.isNotEmpty) ...[
              const Divider(height: 12),
              _headerRow(Icons.local_shipping, 'Delivery Date', _deliveryDate),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildItemCard(int index, InvoiceLineItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with index and delete
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(item.description,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fields grid
          _editableField(index, 'Item Code / ID', item.itemCode,
              (v) => setState(() => _items[index].itemCode = v)),
          _editableField(index, 'Description', item.description,
              (v) => setState(() => _items[index].description = v)),
          Row(
            children: [
              Expanded(
                child: _editableField(index, 'Qty', item.quantity,
                    (v) => setState(() => _items[index].quantity = v)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _editableField(index, 'Amount', item.amount,
                    (v) => setState(() => _items[index].amount = v)),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _editableField(index, 'Batch / Lot No.', item.batchNo,
                    (v) => setState(() => _items[index].batchNo = v)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _editableField(index, 'Expiry Date', item.expiryDate,
                    (v) => setState(() => _items[index].expiryDate = v)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableField(
      int index, String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextFormField(
        initialValue: value,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: const Color(0xFFF8F9FF),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0D47A1))),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0D47A1),
        letterSpacing: 1.1,
      ),
    );
  }
}