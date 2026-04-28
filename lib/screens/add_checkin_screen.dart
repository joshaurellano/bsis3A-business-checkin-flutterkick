import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:convert';

class AddCheckInScreen extends StatefulWidget {
  const AddCheckInScreen({super.key});

  @override
  State<AddCheckInScreen> createState() => _AddCheckInScreenState();
}

class _AddCheckInScreenState extends State<AddCheckInScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _supplierNameController = TextEditingController();
  final _noteController = TextEditingController();
  final _expiryDateController = TextEditingController();
  final _genericNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _sellingPriceController = TextEditingController();

  // State
  File? _selectedImage;
  double? _lat;
  double? _lng;
  String _stockStatus = 'OK';
  String _dosageForm = 'Capsule';
  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool _isScanning = false;

  final List<String> _stockStatusOptions = ['OK', 'Near Expiry', 'Expired'];
  final List<String> _dosageFormOptions = ['Capsule', 'Tablet', 'Syrup'];

  String get _proofLabel {
    final date = DateFormat('MMdd').format(DateTime.now());
    return 'FlutterKick-MedLog-$date';
  }

  @override
  void dispose() {
    _supplierNameController .dispose();
    _noteController.dispose();
    _expiryDateController.dispose();
    _genericNameController.dispose();
    _brandNameController.dispose();
    _sellingPriceController.dispose();
    super.dispose();
  }

  // ─── OCR ─────────────────────────────────────────────────────────────────────

  Future<void> _extractExpiryFromImage(File imageFile) async {
    setState(() => _isScanning = true);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer();
      final recognized = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final text = recognized.text;
      debugPrint('OCR result: $text');

      // Extract expiry date
      final expiry = _parseExpiryDate(text);
      if (expiry != null) {
        setState(() => _expiryDateController.text = expiry);
        _showSnack('Expiry date detected: $expiry');
      } else {
        _showSnack('Could not detect expiry date. Please enter manually.', isError: true);
      }

      // Extract generic name
      final genericName = _parseGenericName(text);
      if (genericName != null && _genericNameController.text.trim().isEmpty) {
        setState(() => _genericNameController.text = genericName);
        _showSnack('Generic name detected: $genericName');
      }

      // Extract brand name
      final brandName = _parseBrandName(text);
      if (brandName != null && _brandNameController.text.trim().isEmpty) {
        setState(() => _brandNameController.text = brandName);
        _showSnack('Brand name detected: $brandName');
      }


    } catch (e) {
      debugPrint('OCR error: $e');
      _showSnack('OCR failed. Please fill in manually.', isError: true);
    } finally {
      setState(() => _isScanning = false);
    }
  }

  // ─── Parsers ─────────────────────────────────────────────────────────────────

  String? _parseExpiryDate(String text) {
    final patterns = [
      RegExp(r'(?:exp(?:iry)?(?:\s*date)?|best before|bb|use before)[:\s]*(\d{1,2}[\/\-]\d{2,4})', caseSensitive: false),
      RegExp(r'(?:exp(?:iry)?(?:\s*date)?|best before|bb|use before)[:\s]*(\d{4}[\/\-]\d{1,2})', caseSensitive: false),
      RegExp(r'(\d{2}[\/\-]\d{4})'),
      RegExp(r'(\d{4}[\/\-]\d{2})'),
      RegExp(r'(\d{2}[\/\-]\d{2})'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1) ?? match.group(0);
      }
    }
    return null;
  }

  String? _parseGenericName(String text) {
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final medicineKeywords = [
      'acid', 'sodium', 'potassium', 'calcium', 'magnesium', 'zinc',
      'hydrochloride', 'hcl', 'sulfate', 'phosphate', 'citrate',
      'amlodipine', 'losartan', 'metformin', 'amoxicillin', 'mefenamic',
      'paracetamol', 'ibuprofen', 'cetirizine', 'omeprazole', 'atorvastatin',
      'vitamin', 'minerals', 'cholecalciferol', 'ascorbic', 'ferrous',
      'mg', 'mcg', 'tablet', 'capsule', 'syrup', 'suspension',
    ];

    final skipKeywords = [
      'exp', 'expiry', 'expiration', 'batch', 'lot', 'mfg',
      'manufactured', 'best before', 'use before', 'store', 'keep',
      'warning', 'caution', 'directions', 'ingredients', 'www', 'http',
      'tel', 'fax', 'reg', 'lic', 'distributed', 'imported', 'inc',
      'ltd', 'corp', 'pharma', 'laboratories', 'tamper', 'resistant',
      'protection', 'seal', 'broken', 'accept', 'do not', 'for your',
      'manufactured by', 'distributed by',
    ];

    final manufacturerKeywords = [
      'unilab', 'gsk', 'pfizer', 'sanofi', 'novartis', 'roche',
      'abbott', 'bayer', 'merck', 'nelpa', 'sai', 'kopran', 'despina',
      'parenterals', 'lifesciences',
    ];

    String? bestCandidate;
    int bestScore = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      if (line.length < 3) continue;
      if (RegExp(r'^\d+$').hasMatch(line)) continue;
      if (RegExp(r'\d{2}[\/\-]\d{2,4}').hasMatch(line)) continue;
      if (skipKeywords.any((kw) => lower.contains(kw))) continue;
      if (manufacturerKeywords.any((kw) => lower == kw || lower.startsWith('$kw '))) continue;

      int score = 0;

      for (final kw in medicineKeywords) {
        if (lower.contains(kw)) {
          score += 10;
          break;
        }
      }

      if (line.contains('+')) score += 8;
      if (line == line.toUpperCase() && line.length > 4) score += 5;
      if (line[0] == line[0].toUpperCase()) score += 3;

      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1].toLowerCase();
        if (RegExp(r'\d+\s*(mg|mcg|ml|g)\b').hasMatch(nextLine)) {
          score += 15;
        }
      }

      if (line.length < 5) score -= 5;
      final digitCount = line.replaceAll(RegExp(r'\D'), '').length;
      if (digitCount > line.length / 2) score -= 10;

      if (score > bestScore) {
        bestScore = score;
        bestCandidate = line;
      }
    }

    if (bestCandidate != null && bestScore >= 10) return bestCandidate;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (line.length < 4) continue;
      if (manufacturerKeywords.any((kw) => lower == kw || lower.startsWith('$kw '))) continue;
      if (skipKeywords.any((kw) => lower.contains(kw))) continue;
      if (RegExp(r'\d{2}[\/\-]\d{2,4}').hasMatch(line)) continue;
      return line;
    }

    return null;
  }

  String? _parseBrandName(String text) {
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final skipKeywords = [
      'exp', 'expiry', 'batch', 'lot', 'mfg', 'manufactured', 'store',
      'warning', 'caution', 'directions', 'www', 'http', 'tel', 'fax',
      'distributed', 'imported', 'tamper', 'resistant', 'protection',
      'seal', 'broken', 'accept', 'do not', 'for your', 'mg', 'mcg',
      'tablet', 'capsule', 'film-coated', 'enteric', 'proton pump',
      'angiotensin', 'receptor', 'blocker', 'channel', 'inhibitor',
      'anti-inflammatory', 'non-steroid', 'fenamate', 'supplement',
    ];

    final genericName = _parseGenericName(text)?.toLowerCase();
    int genericIndex = -1;
    if (genericName != null) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains(genericName.split(' ').first)) {
          genericIndex = i;
          break;
        }
      }
    }

    final searchStart = genericIndex >= 0 ? genericIndex + 1 : 0;
    for (int i = searchStart; i < lines.length && i < searchStart + 4; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();
      if (line.length < 3) continue;
      if (RegExp(r'\d{2}[\/\-]\d{2,4}').hasMatch(line)) continue;
      if (skipKeywords.any((kw) => lower.contains(kw))) continue;
      if (line.length > 2 && line.length < 40) return line;
    }
    return null;
  }

  // ─── Camera / Gallery ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked != null) {
      final file = File(picked.path);
      setState(() => _selectedImage = file);
      _showSnack('Scanning medicine package...');
      await _extractExpiryFromImage(file);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF0D47A1)),
              title: const Text('Take Photo'),
              subtitle: const Text('Camera will scan the medicine package automatically'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0D47A1)),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick a photo to scan the medicine package'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── GPS ─────────────────────────────────────────────────────────────────────

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack('Location services are disabled.', isError: true);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied.', isError: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack('Location permanently denied. Enable in settings.', isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
      _showSnack('Location captured!');
    } catch (e) {
      _showSnack('Failed to get location: $e', isError: true);
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      _showSnack('Please capture or select a photo.', isError: true);
      return;
    }
    if (_lat == null || _lng == null) {
      _showSnack('Please get GPS location first.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final docRef = FirebaseFirestore.instance.collection('medicine_logs').doc();
      final docId = docRef.id;

      await docRef.set({
        'id': docId,
        'supplierName': _supplierNameController.text.trim(),
        'genericName': _genericNameController.text.trim(),
        'brandName': _brandNameController.text.trim(),
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'photoBase64': base64Image,
        'lat': _lat,
        'lng': _lng,
        'proofLabel': _proofLabel,
        'dosageForm': _dosageForm,
        'sellingPrice': _sellingPriceController.text,
        'expiryDate': _expiryDateController.text.trim(),
        'stockStatus': _stockStatus,
        'createdBy': user?.uid,
      });

      if (mounted) {
        _showSnack('Check-in saved successfully!');
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('SAVE ERROR: $e');
      debugPrint('SAVE ERROR TYPE: ${e.runtimeType}');
      _showSnack('Save failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        title: const Text('Add Check-In'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Proof Label ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Proof: $_proofLabel',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Required Fields ──
              _sectionLabel('REQUIRED FIELDS'),
              const SizedBox(height: 8),

              _buildTextField(
                controller: _supplierNameController ,
                label: 'Business / Pharmacy Name',
                icon: Icons.business,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              _buildTextField(
                controller: _noteController,
                label: 'Note',
                icon: Icons.notes,
                maxLines: 3,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              // ── Photo + OCR ──
              _sectionLabel('PHOTO  •  TAP TO SCAN MEDICINE PACKAGE'),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _isScanning ? null : _showImageSourceSheet,
                child: Container(
                  width: double.infinity,
                  height: 200,
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
                            Text('Scanning medicine package...',
                                style: TextStyle(color: Colors.grey)),
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
                                Icon(Icons.document_scanner, size: 48, color: Colors.grey[400]),
                                const SizedBox(height: 8),
                                Text('Tap to capture medicine package',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                const SizedBox(height: 4),
                                Text('Generic name, brand & expiry will be auto-detected',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                              ],
                            ),
                ),
              ),

              if (_selectedImage != null && !_isScanning) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('Photo captured', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                    const Spacer(),
                    TextButton(
                      onPressed: _showImageSourceSheet,
                      child: const Text('Retake', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // ── Medicine Details ──
              _sectionLabel('MEDICINE DETAILS'),
              const SizedBox(height: 8),

              // Generic Name
              _buildTextField(
                controller: _genericNameController,
                label: 'Generic Name',
                icon: Icons.science,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 6),
              Text(
                'Auto-filled by OCR scan. Tap to correct if needed.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

              // Brand Name
              _buildTextField(
                controller: _brandNameController,
                label: 'Brand Name',
                icon: Icons.label,
              ),
              const SizedBox(height: 6),
              Text(
                'Auto-filled by OCR scan. Tap to correct if needed.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),


              // Expiry Date
              TextFormField(
                controller: _expiryDateController,
                readOnly: false,
                onTap: _pickExpiryDate,
                decoration: InputDecoration(
                  labelText: 'Expiry Date',
                  hintText: 'Auto-filled from scan or tap to pick',
                  prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF0D47A1)),
                  suffixIcon: _isScanning
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.edit_calendar, color: Color(0xFF0D47A1)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D47A1)),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 6),
              Text(
                'Auto-filled by OCR scan. Tap to correct if needed.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

              // Selling Price 
              _buildTextField(
                controller: _sellingPriceController,
                label: 'Selling Price',
                icon: Icons.label,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 20),

              // Dosage Form dropdown
              DropdownButtonFormField<String>(
                initialValue: _dosageForm,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Dosage Form',
                  prefixIcon: const Icon(Icons.inventory_2, color: Color(0xFF0D47A1)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D47A1)),
                  ),
                ),
                items: _dosageFormOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _dosageForm = v!),
              ),
              const SizedBox(height: 20),

              // Stock Status dropdown
              DropdownButtonFormField<String>(
                initialValue: _stockStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Stock Status',
                  prefixIcon: const Icon(Icons.inventory_2, color: Color(0xFF0D47A1)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0D47A1)),
                  ),
                ),
                items: _stockStatusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _stockStatus = v!),
              ),
              const SizedBox(height: 20),

              // ── GPS ──
              _sectionLabel('LOCATION'),
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGettingLocation ? null : _getLocation,
                  icon: _isGettingLocation
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _lat != null ? Icons.location_on : Icons.location_searching,
                          color: _lat != null ? Colors.green : const Color(0xFF0D47A1),
                        ),
                  label: Text(
                    _isGettingLocation
                        ? 'Getting location...'
                        : _lat != null
                            ? 'Location captured ✓'
                            : 'Get GPS Location',
                    style: TextStyle(
                      color: _lat != null ? Colors.green : const Color(0xFF0D47A1),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: _lat != null ? Colors.green : const Color(0xFF0D47A1),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white,
                  ),
                ),
              ),

              if (_lat != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Text(
                        'lat: ${_lat!.toStringAsFixed(6)}  •  lng: ${_lng!.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            SizedBox(width: 12),
                            Text('Saving...', style: TextStyle(fontSize: 16)),
                          ],
                        )
                      : const Text('Save Check-In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0D47A1)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D47A1)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}