enum ReturnStatus { none, pending, scheduled, completed }
enum ProductStatus { good, expiringSoon, expired }

class Product {
  final String id;
  final String name;
  final String supplier;
  final String batchNumber;
  final int stock;
  final double purchasePrice;
  final double sellingPrice;
  final DateTime manufactureDate;
  final DateTime expiryDate;
  final DateTime? dateAdded;
  final ReturnStatus returnStatus;
  final String? returnReason;
  final DateTime? returnDate;

  Product({
    required this.id,
    required this.name,
    required this.supplier,
    required this.batchNumber,
    required this.stock,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.manufactureDate,
    required this.expiryDate,
    this.dateAdded,
    this.returnStatus = ReturnStatus.none,
    this.returnReason,
    this.returnDate,
  });

  int get daysUntilExpiry {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  int get daysSinceManufacture {
    return DateTime.now().difference(manufactureDate).inDays;
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

  double get totalValue {
    return stock * purchasePrice;
  }

  double get potentialProfit {
    return stock * (sellingPrice - purchasePrice);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'supplier': supplier,
      'batchNumber': batchNumber,
      'stock': stock,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'manufactureDate': manufactureDate.toIso8601String(),
      'expiryDate': expiryDate.toIso8601String(),
      'dateAdded': dateAdded?.toIso8601String(),
      'returnStatus': returnStatus.index,
      'returnReason': returnReason,
      'returnDate': returnDate?.toIso8601String(),
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      supplier: json['supplier'],
      batchNumber: json['batchNumber'],
      stock: json['stock'],
      purchasePrice: json['purchasePrice'].toDouble(),
      sellingPrice: json['sellingPrice'].toDouble(),
      manufactureDate: DateTime.parse(json['manufactureDate']),
      expiryDate: DateTime.parse(json['expiryDate']),
      dateAdded: json['dateAdded'] != null ? DateTime.parse(json['dateAdded']) : null,
      returnStatus: ReturnStatus.values[json['returnStatus']],
      returnReason: json['returnReason'],
      returnDate: json['returnDate'] != null ? DateTime.parse(json['returnDate']) : null,
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? supplier,
    String? batchNumber,
    int? stock,
    double? purchasePrice,
    double? sellingPrice,
    DateTime? manufactureDate,
    DateTime? expiryDate,
    DateTime? dateAdded,
    ReturnStatus? returnStatus,
    String? returnReason,
    DateTime? returnDate,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      supplier: supplier ?? this.supplier,
      batchNumber: batchNumber ?? this.batchNumber,
      stock: stock ?? this.stock,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      manufactureDate: manufactureDate ?? this.manufactureDate,
      expiryDate: expiryDate ?? this.expiryDate,
      dateAdded: dateAdded ?? this.dateAdded,
      returnStatus: returnStatus ?? this.returnStatus,
      returnReason: returnReason ?? this.returnReason,
      returnDate: returnDate ?? this.returnDate,
    );
  }

  static List<Product> generateMockData() {
    return [
      Product(
        id: 'PRD001',
        name: 'Paracetamol 500mg',
        supplier: 'MediSupply Corp',
        batchNumber: 'BATCH-2024-001',
        stock: 150,
        purchasePrice: 3.50,
        sellingPrice: 5.50,
        manufactureDate: DateTime(2024, 1, 15),
        expiryDate: DateTime.now().add(const Duration(days: 15)),
        dateAdded: DateTime(2024, 1, 20),
      ),
      Product(
        id: 'PRD002',
        name: 'Amoxicillin 250mg',
        supplier: 'PharmaDistributors Inc',
        batchNumber: 'BATCH-2024-002',
        stock: 80,
        purchasePrice: 8.50,
        sellingPrice: 12.75,
        manufactureDate: DateTime(2024, 2, 1),
        expiryDate: DateTime.now().add(const Duration(days: 45)),
        dateAdded: DateTime(2024, 2, 5),
      ),
      Product(
        id: 'PRD003',
        name: 'Vitamin C 1000mg',
        supplier: 'HealthPlus Trading',
        batchNumber: 'BATCH-2024-003',
        stock: 200,
        purchasePrice: 5.00,
        sellingPrice: 8.25,
        manufactureDate: DateTime(2023, 12, 10),
        expiryDate: DateTime.now().add(const Duration(days: -5)),
        dateAdded: DateTime(2023, 12, 15),
        returnStatus: ReturnStatus.pending,
        returnReason: 'Expired product',
        returnDate: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Product(
        id: 'PRD004',
        name: 'Antibiotic Cream',
        supplier: 'MediSupply Corp',
        batchNumber: 'BATCH-2024-004',
        stock: 45,
        purchasePrice: 10.00,
        sellingPrice: 15.00,
        manufactureDate: DateTime(2024, 2, 20),
        expiryDate: DateTime.now().add(const Duration(days: 10)),
        dateAdded: DateTime(2024, 2, 25),
      ),
      Product(
        id: 'PRD005',
        name: 'Insulin Injections',
        supplier: 'DiabetesCare Ltd',
        batchNumber: 'BATCH-2024-005',
        stock: 30,
        purchasePrice: 35.00,
        sellingPrice: 45.50,
        manufactureDate: DateTime(2024, 1, 5),
        expiryDate: DateTime.now().add(const Duration(days: 90)),
        dateAdded: DateTime(2024, 1, 10),
      ),
      Product(
        id: 'PRD006',
        name: 'Blood Pressure Monitor',
        supplier: 'MedTech Solutions',
        batchNumber: 'BATCH-2024-006',
        stock: 12,
        purchasePrice: 450.00,
        sellingPrice: 599.00,
        manufactureDate: DateTime(2024, 1, 20),
        expiryDate: DateTime.now().add(const Duration(days: 180)),
        dateAdded: DateTime(2024, 1, 25),
      ),
    ];
  }
}