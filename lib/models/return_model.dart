enum ReturnType { expiry, damage, overstock, qualityIssue, other }
enum ReturnStatus { pending, approved, pickedUp, completed, rejected }

class ReturnRequest {
  final String id;
  final String productId;
  final String productName;
  final String supplier;
  final int quantity;
  final ReturnType returnType;
  final String reason;
  final DateTime requestDate;
  ReturnStatus status;
  DateTime? approvalDate;
  DateTime? pickupDate;
  String? rejectionReason;
  double? refundAmount;

  ReturnRequest({
    required this.id,
    required this.productId,
    required this.productName,
    required this.supplier,
    required this.quantity,
    required this.returnType,
    required this.reason,
    required this.requestDate,
    this.status = ReturnStatus.pending,
    this.approvalDate,
    this.pickupDate,
    this.rejectionReason,
    this.refundAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'supplier': supplier,
      'quantity': quantity,
      'returnType': returnType.index,
      'reason': reason,
      'requestDate': requestDate.toIso8601String(),
      'status': status.index,
      'approvalDate': approvalDate?.toIso8601String(),
      'pickupDate': pickupDate?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'refundAmount': refundAmount,
    };
  }

  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    return ReturnRequest(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'],
      supplier: json['supplier'],
      quantity: json['quantity'],
      returnType: ReturnType.values[json['returnType']],
      reason: json['reason'],
      requestDate: DateTime.parse(json['requestDate']),
      status: ReturnStatus.values[json['status']],
      approvalDate: json['approvalDate'] != null ? DateTime.parse(json['approvalDate']) : null,
      pickupDate: json['pickupDate'] != null ? DateTime.parse(json['pickupDate']) : null,
      rejectionReason: json['rejectionReason'],
      refundAmount: json['refundAmount']?.toDouble(),
    );
  }
}