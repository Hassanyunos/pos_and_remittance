import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/features/remittance_management/application/remittance_service.dart';
import 'package:pos_and_remittance/features/remittance_management/data/models/remittance.dart';

void main() {
  group('RemittanceService validation', () {
    test('rejects empty reference number', () {
      expect(
        () => RemittanceService.instance.validateRemittanceInput(referenceNumber: '   ', amount: 10, charge: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects non-positive amount', () {
      expect(
        () => RemittanceService.instance.validateRemittanceInput(referenceNumber: 'REF-1', amount: 0, charge: 0),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects negative charge', () {
      expect(
        () => RemittanceService.instance.validateRemittanceInput(referenceNumber: 'REF-1', amount: 10, charge: -1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('shows not received for cash out pending status', () {
      expect(
        RemittanceService.instance.getStatusLabel(
          RemittanceStatus.pending,
          remittanceType: RemittanceType.cashOut,
        ),
        'Not received',
      );
    });

    test('keeps cash in status fixed to received by customer', () {
      expect(
        RemittanceService.instance.canEditStatus(RemittanceType.cashIn),
        isFalse,
      );
    });

    test('uses received-by-customer for cash-in and not-received for cash-out defaults', () {
      expect(
        RemittanceService.instance.getInitialStatusForType(RemittanceType.cashIn),
        RemittanceStatus.receivedByCustomer,
      );
      expect(
        RemittanceService.instance.getInitialStatusForType(RemittanceType.cashOut),
        RemittanceStatus.pending,
      );
    });
  });
}
