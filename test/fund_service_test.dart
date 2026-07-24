import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/features/fund_management/application/fund_service.dart';

void main() {
  group('FundService zakah calculation', () {
    test('returns zero when total assets are below the nisab threshold', () {
      final amount = FundService.instance.calculateZakahAmount(
        totalAssets: 1000,
        goldPricePerGram: 100,
        silverPricePerGram: 10,
      );

      expect(amount, 0.0);
    });

    test('returns 2.5 percent when total assets reach or exceed nisab', () {
      final amount = FundService.instance.calculateZakahAmount(
        totalAssets: 100000,
        goldPricePerGram: 100,
        silverPricePerGram: 10,
      );

      expect(amount, 2500.0);
    });

    test('returns an eligibility message when total assets are below nisab', () {
      final message = FundService.instance.validateZakatEligibility(
        totalAssets: 1000,
        goldPricePerGram: 100,
        silverPricePerGram: 10,
      );

      expect(message, contains('nisab'));
    });

    test('returns a yearly eligibility message when the prior zakat was too recent', () {
      final message = FundService.instance.validateZakatEligibility(
        totalAssets: 100000,
        goldPricePerGram: 100,
        silverPricePerGram: 10,
        lastZakahDate: DateTime.now().subtract(const Duration(days: 300)),
      );

      expect(message, contains('year'));
    });
  });
}
