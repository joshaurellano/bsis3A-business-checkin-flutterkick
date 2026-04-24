import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

  final List<String> _stockStatusOptions = ['OK', 'Near Expiry', 'Expired'];

  // Proof label — change GroupName to your actual group name
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

  // ─── Camera / Gallery ───────────────────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
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
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF0D47A1)),
              title: const Text('Choose from Gallery'),
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
      _showSnack('Location services are disabled. Please enable GPS.', isError: true);
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
      _showSnack('Location permission permanently denied. Enable in settings.', isError: true);
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

              // ── Business-Specific Fields ──
              _sectionLabel('MEDICINE DETAILS'),
              const SizedBox(height: 8),

              // Expiry Date picker
              TextFormField(
                controller: _expiryDateController,
                readOnly: true,
                onTap: _pickExpiryDate,
                decoration: InputDecoration(
                  labelText: 'Expiry Date',
                  prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF0D47A1)),
                  suffixIcon: const Icon(Icons.arrow_drop_down, color: Color(0xFF0D47A1)),
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

              // ── Photo ──
              _sectionLabel('PHOTO'),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _showImageSourceSheet,
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
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text('Tap to capture or pick photo',
                                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                          ],
                        ),
                ),
              ),

              if (_selectedImage != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text('Photo selected', style: TextStyle(color: Colors.green[700], fontSize: 12)),
                    const Spacer(),
                    TextButton(
                      onPressed: _showImageSourceSheet,
                      child: const Text('Change', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
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