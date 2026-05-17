import 'package:flutter_test/flutter_test.dart';
import 'package:bsis3a_business_checkin_flutterkick/models/product_model.dart';

Product makeProduct({required String expiryDate, ReturnStatus returnStatus = ReturnStatus.none}) {
  return Product(
    id: 'test-id',
    genericName: 'Test Med',
    brandName: '',
    supplierName: 'Supplier A',
    dosageForm: 'Tablet',
    sellingPrice: '10.00',
    expiryDate: expiryDate,
    stockStatus: 'Available',
    note: '',
    proofLabel: '',
    createdBy: 'user1',
    returnStatus: returnStatus,
  );
}

void main() {
  group('Product.parsedExpiryDate', () {
    test('parses ISO date string correctly', () {
      final p = makeProduct(expiryDate: '2030-06-15');
      expect(p.parsedExpiryDate, DateTime(2030, 6, 15));
    });

    test('parses MM/yyyy format', () {
      final p = makeProduct(expiryDate: '06/2030');
      expect(p.parsedExpiryDate.year, 2030);
      expect(p.parsedExpiryDate.month, 6);
    });

    test('empty expiry defaults to now + 365 days', () {
      final p = makeProduct(expiryDate: '');
      final expected = DateTime.now().add(const Duration(days: 365));
      expect(p.parsedExpiryDate.year, expected.year);
      expect(p.parsedExpiryDate.month, expected.month);
    });

    test('garbage string defaults to now + 365 days', () {
      final p = makeProduct(expiryDate: 'not-a-date');
      final expected = DateTime.now().add(const Duration(days: 365));
      expect(p.parsedExpiryDate.year, expected.year);
    });
  });

  group('Product.returnDeadline', () {
    test('subtracts 6 months from expiry', () {
      final p = makeProduct(expiryDate: '2026-12-01');
      expect(p.returnDeadline, DateTime(2026, 6, 1));
    });

    test('rolls over year when month goes below 1', () {
      final p = makeProduct(expiryDate: '2026-03-01');
      expect(p.returnDeadline, DateTime(2025, 9, 1));
    });

    test('clamps day when target month is shorter (Aug 31 → Feb 28)', () {
      final p = makeProduct(expiryDate: '2026-08-31');
      expect(p.returnDeadline.month, 2);
      expect(p.returnDeadline.day, 28);
    });
  });

  group('Product.returnWindowStatus', () {
    test('expired product returns expired status', () {
      final p = makeProduct(expiryDate: '2020-01-01');
      expect(p.returnWindowStatus, ReturnWindowStatus.expired);
    });

    test('product expiring far away is returnable', () {
      final future = DateTime.now().add(const Duration(days: 365));
      final p = makeProduct(expiryDate: future.toIso8601String());
      expect(p.returnWindowStatus, ReturnWindowStatus.returnable);
    });

    test('product expiring in 4 months is windowClosed', () {
      final future = DateTime.now().add(const Duration(days: 120));
      final p = makeProduct(expiryDate: future.toIso8601String());
      expect(p.returnWindowStatus, ReturnWindowStatus.windowClosed);
    });

    test('product with return deadline in 15 days is returnSoon', () {
      // Return deadline = expiry - 6 months. So set expiry = 6 months + 15 days from now.
      final future = DateTime.now().add(const Duration(days: 195));
      final p = makeProduct(expiryDate: future.toIso8601String());
      expect(p.returnWindowStatus, ReturnWindowStatus.returnSoon);
    });
  });

  group('Product.isReturnable', () {
    test('returnable when returnWindowStatus is returnable', () {
      final future = DateTime.now().add(const Duration(days: 365));
      final p = makeProduct(expiryDate: future.toIso8601String());
      expect(p.isReturnable, true);
    });

    test('not returnable when window is closed', () {
      final future = DateTime.now().add(const Duration(days: 120));
      final p = makeProduct(expiryDate: future.toIso8601String());
      expect(p.isReturnable, false);
    });

    test('not returnable when product is expired', () {
      final p = makeProduct(expiryDate: '2020-01-01');
      expect(p.isReturnable, false);
    });
  });

  group('Product.fromJson', () {
    test('maps all fields from valid json', () {
      final json = {
        'id': 'abc',
        'genericName': 'Amoxicillin',
        'brandName': 'Amoxil',
        'supplierName': 'PharmaCo',
        'dosageForm': 'Capsule',
        'sellingPrice': '25.00',
        'expiryDate': '2027-01-01',
        'stockStatus': 'Available',
        'note': '',
        'proofLabel': '',
        'createdBy': 'uid123',
        'returnStatus': 0,
      };
      final p = Product.fromJson(json);
      expect(p.genericName, 'Amoxicillin');
      expect(p.returnStatus, ReturnStatus.none);
    });

    test('missing genericName defaults to Unknown', () {
      final p = Product.fromJson({'id': 'x'});
      expect(p.genericName, 'Unknown');
    });

    test('missing returnStatus defaults to ReturnStatus.none', () {
      final p = Product.fromJson({'id': 'x'});
      expect(p.returnStatus, ReturnStatus.none);
    });

    test('returnStatus index 2 maps to scheduled', () {
      final p = Product.fromJson({'id': 'x', 'returnStatus': 2});
      expect(p.returnStatus, ReturnStatus.scheduled);
    });
  });
}