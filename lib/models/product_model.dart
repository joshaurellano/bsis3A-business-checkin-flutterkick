import 'package:cloud_firestore/cloud_firestore.dart';

enum ReturnStatus { none, pending, scheduled, completed }
enum ProductStatus { good, expiringSoon, expired }

class Product {
  final String id;
  final String genericName;
  final String brandName;
  final String supplierName;
  final String dosageForm;
  final String sellingPrice;
  final String expiryDate;
  final String stockStatus;
  final String note;
  final String proofLabel;
  final String createdBy;
  final double? lat;
  final double? lng;
  final DateTime? createdAt;
  final ReturnStatus returnStatus;
  final String? returnReason;
  final DateTime? returnDate;

  Product({
    required this.id,
    required this.genericName,
    required this.brandName,
    required this.supplierName,
    required this.dosageForm,
    required this.sellingPrice,
    required this.expiryDate,
    required this.stockStatus,
    required this.note,
    required this.proofLabel,
    required this.createdBy,
    this.lat,
    this.lng,
    this.createdAt,
    this.returnStatus = ReturnStatus.none,
    this.returnReason,
    this.returnDate,
  });

  // ─── Computed ─────────────────────────────────────────────────────────────

  DateTime get parsedExpiryDate => _parseExpiryDate(expiryDate);

  int get daysUntilExpiry {
    return parsedExpiryDate.difference(DateTime.now()).inDays;
  }

  ProductStatus get status {
    if (daysUntilExpiry <= 0) return ProductStatus.expired;
    if (daysUntilExpiry <= 30) return ProductStatus.expiringSoon;
    return ProductStatus.good;
  }

  bool get eligibleForReturn {
    return (daysUntilExpiry <= 30 || daysUntilExpiry <= 0) &&
        returnStatus != ReturnStatus.completed;
  }

  // ─── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'genericName': genericName,
      'brandName': brandName,
      'supplierName': supplierName,
      'dosageForm': dosageForm,
      'sellingPrice': sellingPrice,
      'expiryDate': expiryDate,
      'stockStatus': stockStatus,
      'note': note,
      'proofLabel': proofLabel,
      'createdBy': createdBy,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt?.toIso8601String(),
      'returnStatus': returnStatus.index,
      'returnReason': returnReason,
      'returnDate': returnDate?.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      genericName: json['genericName'] ?? 'Unknown',
      brandName: json['brandName'] ?? '',
      supplierName: json['supplierName'] ?? 'Unknown',
      dosageForm: json['dosageForm'] ?? 'Tablet',
      sellingPrice: json['sellingPrice']?.toString() ?? '0.00',
      expiryDate: json['expiryDate']?.toString() ?? '',
      stockStatus: json['stockStatus'] ?? 'OK',
      note: json['note'] ?? '',
      proofLabel: json['proofLabel'] ?? '',
      createdBy: json['createdBy'] ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      returnStatus: ReturnStatus.values[json['returnStatus'] ?? 0],
      returnReason: json['returnReason'],
      returnDate: json['returnDate'] != null
          ? DateTime.tryParse(json['returnDate'])
          : null,
    );
  }

  static DateTime _parseExpiryDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return DateTime.now().add(const Duration(days: 365));
    }
    // Try ISO format first (yyyy-MM-dd)
    final iso = DateTime.tryParse(value.toString());
    if (iso != null) return iso;
    // Try MM/YYYY or YYYY/MM or MM/YY
    try {
      final parts = value.toString().split(RegExp(r'[\/\-]'));
      if (parts.length == 2) {
        final a = int.tryParse(parts[0]) ?? 1;
        final b = int.tryParse(parts[1]) ?? 2025;
        if (a > 12) return DateTime(a, b);
        if (b > 12) return DateTime(b, a);
        return DateTime(2000 + b, a);
      }
    } catch (_) {}
    return DateTime.now().add(const Duration(days: 365));
  }

  Product copyWith({
    String? id,
    String? genericName,
    String? brandName,
    String? supplierName,
    String? dosageForm,
    String? sellingPrice,
    String? expiryDate,
    String? stockStatus,
    String? note,
    String? proofLabel,
    String? createdBy,
    double? lat,
    double? lng,
    DateTime? createdAt,
    ReturnStatus? returnStatus,
    String? returnReason,
    DateTime? returnDate,
  }) {
    return Product(
      id: id ?? this.id,
      genericName: genericName ?? this.genericName,
      brandName: brandName ?? this.brandName,
      supplierName: supplierName ?? this.supplierName,
      dosageForm: dosageForm ?? this.dosageForm,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      expiryDate: expiryDate ?? this.expiryDate,
      stockStatus: stockStatus ?? this.stockStatus,
      note: note ?? this.note,
      proofLabel: proofLabel ?? this.proofLabel,
      createdBy: createdBy ?? this.createdBy,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      returnStatus: returnStatus ?? this.returnStatus,
      returnReason: returnReason ?? this.returnReason,
      returnDate: returnDate ?? this.returnDate,
    );
  }

  static List<Product> generateMockData() {
    return [
      Product(
        id: 'PRD001',
        genericName: 'Paracetamol',
        brandName: 'Biogesic',
        supplierName: 'Unilab',
        dosageForm: 'Tablet',
        sellingPrice: '5.50',
        expiryDate: '2025-06-15',
        stockStatus: 'Near Expiry',
        note: 'Fast moving item',
        proofLabel: 'FlutterKick-MedLog-0428',
        createdBy: 'uid_demo',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Product(
        id: 'PRD002',
        genericName: 'Amoxicillin',
        brandName: 'Amoxil',
        supplierName: 'GSK',
        dosageForm: 'Capsule',
        sellingPrice: '12.75',
        expiryDate: '2026-03-01',
        stockStatus: 'OK',
        note: 'Keep refrigerated',
        proofLabel: 'FlutterKick-MedLog-0428',
        createdBy: 'uid_demo',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Product(
        id: 'PRD003',
        genericName: 'Omeprazole',
        brandName: 'Inhibita',
        supplierName: 'Nelpa Lifesciences',
        dosageForm: 'Capsule',
        sellingPrice: '8.00',
        expiryDate: '2024-12-01',
        stockStatus: 'Expired',
        note: 'For return processing',
        proofLabel: 'FlutterKick-MedLog-0428',
        createdBy: 'uid_demo',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        returnStatus: ReturnStatus.pending,
        returnReason: 'Expired product',
        returnDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Product(
        id: 'PRD004',
        genericName: 'Losartan Potassium',
        brandName: 'Losan 50',
        supplierName: 'Despina Pharma',
        dosageForm: 'Tablet',
        sellingPrice: '9.50',
        expiryDate: '2025-05-01',
        stockStatus: 'Near Expiry',
        note: 'Check stock levels',
        proofLabel: 'FlutterKick-MedLog-0428',
        createdBy: 'uid_demo',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Product(
        id: 'PRD005',
        genericName: 'Cholecalciferol + Minerals',
        brandName: 'Caltrate Silver Advance',
        supplierName: 'GSK',
        dosageForm: 'Tablet',
        sellingPrice: '18.00',
        expiryDate: '2027-01-01',
        stockStatus: 'OK',
        note: 'For adults 50+',
        proofLabel: 'FlutterKick-MedLog-0428',
        createdBy: 'uid_demo',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }
}