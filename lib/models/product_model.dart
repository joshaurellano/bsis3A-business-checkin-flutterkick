import 'package:cloud_firestore/cloud_firestore.dart';

enum ReturnStatus { none, pending, scheduled, completed }
enum ProductStatus { good, expiringSoon, expired }

// Return window is 6 months before expiry.
// Meds with less than 6 months to expiry cannot be returned.
enum ReturnWindowStatus {
  returnable,    // > 6 months to expiry — still within return window
  returnSoon,    // 6 months to expiry, window closing within 30 days
  windowClosed,  // past the 6-month mark, can no longer be returned
  expired,       // already expired
}

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
  final String? updatedBy;
  final double? lat;
  final double? lng;
  final DateTime? createdAt;
  final DateTime? updatedAt;
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
    this.updatedBy,
    this.updatedAt,
    this.returnStatus = ReturnStatus.none,
    this.returnReason,
    this.returnDate,
  });

  // ─── Expiry computed ──────────────────────────────────────────────────────

  DateTime get parsedExpiryDate => _parseExpiryDate(expiryDate);

  int get daysUntilExpiry =>
      parsedExpiryDate.difference(DateTime.now()).inDays;

  ProductStatus get status {
    if (daysUntilExpiry <= 0) return ProductStatus.expired;
    if (daysUntilExpiry <= 30) return ProductStatus.expiringSoon;
    return ProductStatus.good;
  }

  // ─── Return window computed ───────────────────────────────────────────────
  // Return deadline = expiry date minus 6 months.
  // If today is past that deadline, the return window is closed.

  DateTime get returnDeadline {
    final expiry = parsedExpiryDate;
    // Subtract 6 months safely
    int month = expiry.month - 6;
    int year = expiry.year;
    if (month <= 0) {
      month += 12;
      year -= 1;
    }
    // Clamp day to valid range for that month
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = expiry.day > lastDay ? lastDay : expiry.day;
    return DateTime(year, month, day);
  }

  int get daysUntilReturnDeadline =>
      returnDeadline.difference(DateTime.now()).inDays;

  ReturnWindowStatus get returnWindowStatus {
    if (daysUntilExpiry <= 0) return ReturnWindowStatus.expired;
    if (daysUntilReturnDeadline <= 0) return ReturnWindowStatus.windowClosed;
    if (daysUntilReturnDeadline <= 30) return ReturnWindowStatus.returnSoon;
    return ReturnWindowStatus.returnable;
  }

  bool get isReturnable =>
      returnWindowStatus == ReturnWindowStatus.returnable ||
      returnWindowStatus == ReturnWindowStatus.returnSoon;

  // ─── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
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
        'updatedBy': updatedBy,
        'lat': lat,
        'lng': lng,
        'createdAt':
            createdAt != null ? Timestamp.fromDate(createdAt!) : null,
        'updatedAt': updatedAt != null
            ? Timestamp.fromDate(updatedAt!)
            : FieldValue.serverTimestamp(),
        'returnStatus': returnStatus.index,
        'returnReason': returnReason,
        'returnDate':
            returnDate != null ? Timestamp.fromDate(returnDate!) : null,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
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
        updatedBy: json['updatedBy'] ?? '',
        updatedAt: json['updatedAt'] is Timestamp
            ? (json['updatedAt'] as Timestamp).toDate()
            : null,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : json['createdAt'] is String
                ? DateTime.tryParse(json['createdAt'])
                : null,
        returnStatus: ReturnStatus.values[json['returnStatus'] ?? 0],
        returnReason: json['returnReason'],
        returnDate: json['returnDate'] is Timestamp
            ? (json['returnDate'] as Timestamp).toDate()
            : json['returnDate'] is String
                ? DateTime.tryParse(json['returnDate'])
                : null,
      );

  static DateTime _parseExpiryDate(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return DateTime.now().add(const Duration(days: 365));
    }
    final iso = DateTime.tryParse(value.toString());
    if (iso != null) return iso;
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
    String? updatedBy,
    double? lat,
    double? lng,
    DateTime? createdAt,
    DateTime? updatedAt,
    ReturnStatus? returnStatus,
    String? returnReason,
    DateTime? returnDate,
  }) =>
      Product(
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