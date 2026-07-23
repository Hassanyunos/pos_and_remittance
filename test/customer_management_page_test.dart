import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/features/customer_management/presentation/pages/customer_management_page.dart';

void main() {
  testWidgets(
      'opens a create customer dialog instead of showing the form inline',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CustomerManagementPage()));
    await tester.pumpAndSettle();

    expect(find.text('Customer details'), findsNothing);
    expect(find.byTooltip('Create customer'), findsOneWidget);

    await tester.tap(find.byTooltip('Create customer'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Create customer'), findsWidgets);
  });
}
