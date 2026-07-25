import 'package:flutter/material.dart';

class LoanManagementPage extends StatelessWidget {
  const LoanManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan management')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_balance_rounded, size: 56, color: Colors.amber),
              SizedBox(height: 16),
              Text('Loan management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'This section will be ready soon so you can track loans, repayments, and balances in one place.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
