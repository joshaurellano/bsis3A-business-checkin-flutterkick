import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:convert';

class AddCheckInScreen extends StatefulWidget {
  const AddCheckInScreen({super.key});

  @override
  State<AddCheckInScreen> createState() => _AddCheckInScreenState();
}

class _AddCheckInScreenState extends State<AddCheckInScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessNameController = TextEditingController();
  final _noteController = TextEditingController();
  final _expiryDateController = TextEditingController();

  // State
  File? _selectedImage;
  double? _lat;
  double? _lng;
  String _stockStatus = 'OK';
  bool _isSaving = false;
  bool _isGettingLocation = false;
  bool _isScanning = false;

  final List<String> _stockStatusOptions = ['OK', 'Near Expiry', 'Expired'];

  String get _proofLabel {
    final date = DateFormat('MMdd').format(DateTime.now());
    return 'FlutterKick-MedLog-$date';
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _noteController.dispose();
    _expiryDateController.dispose();
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

    // Extract medicine name
    final name = _parseMedicineName(text);
    if (name != null && _businessNameController.text.trim().isEmpty) {
      setState(() => _businessNameController.text = name);
      _showSnack('Medicine name detected: $name');
    }

  } catch (e) {
    debugPrint('OCR error: $e');
    _showSnack('OCR failed. Please fill in manually.', isError: true);
  } finally {
    setState(() => _isScanning = false);
  }
}

  String? _parseExpiryDate(String text) {
    final patterns = [
      // Labeled patterns first (highest confidence)
      RegExp(r'(?:exp(?:iry)?(?:\s*date)?|best before|bb|use before)[:\s]*(\d{1,2}[\/\-]\d{2,4})', caseSensitive: false),
      RegExp(r'(?:exp(?:iry)?(?:\s*date)?|best before|bb|use before)[:\s]*(\d{4}[\/\-]\d{1,2})', caseSensitive: false),
      // Unlabeled date patterns
      RegExp(r'(\d{2}[\/\-]\d{4})'),  // 06/2025
      RegExp(r'(\d{4}[\/\-]\d{2})'),  // 2025/06
      RegExp(r'(\d{2}[\/\-]\d{2})'),  // 06/25
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1) ?? match.group(0);
      }
    }
    return null;
  }

  String? _parseMedicineName(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final skipKeywords = [
      'exp', 'expiry', 'expiration', 'batch', 'lot', 'mfg', 'manufactured',
      'best before', 'use before', 'store', 'keep', 'dosage', 'dose',
      'warning', 'caution', 'directions', 'ingredients', 'www', 'http',
      'tel', 'fax', 'reg', 'lic', 'net', 'wt', 'qty',
    ];

    for (final line in lines) {
      final lower = line.toLowerCase();

      // Skip lines with dates
      if (RegExp(r'\d{2}[\/\-]\d{2,4}').hasMatch(line)) continue;
      if (RegExp(r'\d{4}[\/\-]\d{2}').hasMatch(line)) continue;

      // Skip short lines
      if (line.length < 4) continue;

      // Skip lines with skip keywords
      if (skipKeywords.any((kw) => lower.contains(kw))) continue;

      // Skip lines that are mostly numbers
      final digitCount = line.replaceAll(RegExp(r'\D'), '').length;
      if (digitCount > line.length / 2) continue;

      return line;
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
      _showSnack('Scanning for expiry date...');
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
              subtitle: const Text('Camera will scan for expiry date automatically'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0D47A1)),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick a photo to scan for expiry date'),
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
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
        'businessName': _businessNameController.text.trim(),
        'note': _noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'photoBase64': base64Image,
        'lat': _lat,
        'lng': _lng,
        'createdBy': 'FlutterKick',
        'proofLabel': _proofLabel,
        'expiryDate': _expiryDateController.text.trim(),
        'stockStatus': _stockStatus,
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
                controller: _businessNameController,
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
              _sectionLabel('PHOTO  •  TAP TO SCAN EXPIRY DATE'),
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
                            Text('Scanning for expiry date...',
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
                                Text('Expiry date will be auto-detected',
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

              // Expiry Date — auto-filled by OCR, still editable
              Stack(
                children: [
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
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Auto-filled by OCR scan. Tap to correct if needed.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

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
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
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