import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceRecord {
  final String id;
  final String invoiceNumber;
  final String supplierName;
  final String deliveryDate;
  final String invoiceTotal;
  final String itemCode;
  final String description;
  final String quantity;
  final String batchNo;
  final String expiryDate;
  final String amount;
  final DateTime? createdAt;
  final String createdBy;

  InvoiceRecord({
    required this.id,
    required this.invoiceNumber,
    required this.supplierName,
    required this.deliveryDate,
    required this.invoiceTotal,
    required this.itemCode,
    required this.description,
    required this.quantity,
    required this.batchNo,
    required this.expiryDate,
    required this.amount,
    this.createdAt,
    required this.createdBy,
  });

  factory InvoiceRecord.fromMap(String id, Map<String, dynamic> data) =>
      InvoiceRecord(
        id: id,
        invoiceNumber: data['invoiceNumber']?.toString() ?? '',
        supplierName: data['supplierName']?.toString() ?? '',
        deliveryDate: data['deliveryDate']?.toString() ?? '',
        invoiceTotal: data['invoiceTotal']?.toString() ?? '',
        itemCode: data['itemCode']?.toString() ?? '',
        description: data['description']?.toString() ?? '',
        quantity: data['quantity']?.toString() ?? '',
        batchNo: data['batchNo']?.toString() ?? '',
        expiryDate: data['expiryDate']?.toString() ?? '',
        amount: data['amount']?.toString() ?? '',
        createdAt: data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : null,
        createdBy: data['createdBy']?.toString() ?? '',
      );

  DateTime get parsedExpiry {
    if (expiryDate.isEmpty) return DateTime(9999);
    final iso = DateTime.tryParse(expiryDate);
    if (iso != null) return iso;
    try {
      final parts = expiryDate.split(RegExp(r'[\/\-]'));
      if (parts.length == 3) {
        final nums = parts.map((p) => int.tryParse(p) ?? 0).toList();
        if (nums[2] > 99) return DateTime(nums[2], nums[0], nums[1]);
        return DateTime(2000 + nums[2], nums[1], nums[0]);
      }
      if (parts.length == 2) {
        final a = int.tryParse(parts[0]) ?? 1;
        final b = int.tryParse(parts[1]) ?? 2025;
        if (b > 99) return DateTime(b, a);
        if (a > 12) return DateTime(2000 + a, b);
        return DateTime(2000 + b, a);
      }
    } catch (_) {}
    return DateTime(9999);
  }

  bool get isExpired => parsedExpiry.isBefore(DateTime.now());

  bool get isExpiringSoon {
    final diff = parsedExpiry.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 180;
  }
  bool get isReturnable => !isExpired && !isExpiringSoon;
}