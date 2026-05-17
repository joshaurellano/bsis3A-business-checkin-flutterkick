import 'package:flutter_test/flutter_test.dart';
import 'package:bsis3a_business_checkin_flutterkick/models/invoice_record.dart';

InvoiceRecord makeRecord({required String expiryDate}) {
  return InvoiceRecord(
    id: 'r1',
    invoiceNumber: 'INV-001',
    supplierName: 'Supplier',
    deliveryDate: '',
    invoiceTotal: '500',
    itemCode: 'MED01',
    description: 'Test Medicine',
    quantity: '10',
    batchNo: 'BATCH01',
    expiryDate: expiryDate,
    amount: '250',
    createdBy: 'uid1',
  );
}

void main() {
  group('InvoiceRecord.parsedExpiry', () {
    test('parses ISO date', () {
      final r = makeRecord(expiryDate: '2030-06-15');
      expect(r.parsedExpiry, DateTime(2030, 6, 15));
    });

    test('parses MM/dd/yyyy', () {
      final r = makeRecord(expiryDate: '06/15/2030');
      expect(r.parsedExpiry, DateTime(2030, 6, 15));
    });

    test('empty expiry returns DateTime(9999)', () {
      final r = makeRecord(expiryDate: '');
      expect(r.parsedExpiry.year, 9999);
    });

    test('unrecognized format returns DateTime(9999)', () {
      final r = makeRecord(expiryDate: 'notadate');
      expect(r.parsedExpiry.year, 9999);
    });
  });

  group('InvoiceRecord.isExpired', () {
    test('past date is expired', () {
      final r = makeRecord(expiryDate: '2020-01-01');
      expect(r.isExpired, true);
    });

    test('future date is not expired', () {
      final r = makeRecord(expiryDate: '2035-01-01');
      expect(r.isExpired, false);
    });
  });

  group('InvoiceRecord.isExpiringSoon', () {
    test('expiring in 90 days is expiring soon', () {
      final date = DateTime.now().add(const Duration(days: 90));
      final r = makeRecord(expiryDate: date.toIso8601String());
      expect(r.isExpiringSoon, true);
    });

    test('expiring in 200 days is not expiring soon', () {
      final date = DateTime.now().add(const Duration(days: 200));
      final r = makeRecord(expiryDate: date.toIso8601String());
      expect(r.isExpiringSoon, false);
    });

    test('already expired is not expiring soon', () {
      final r = makeRecord(expiryDate: '2020-01-01');
      expect(r.isExpiringSoon, false);
    });
  });
}