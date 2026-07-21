import 'package:flutter_test/flutter_test.dart';
import 'package:pos_and_remittance/app/app.dart';

void main() {
  testWidgets('shows the sign-in page', (tester) async {
    await tester.pumpWidget(const PosAndRemittanceApp());
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Create Account'), findsNothing);
  });
}
