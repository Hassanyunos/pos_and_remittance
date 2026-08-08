import 'package:flutter/material.dart';

import '../../../../core/ui/app_notice.dart';
import '../../application/auth_service.dart';
import '../../../home/presentation/pages/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    final isAuthenticated = await AuthService.instance.signIn(
      accountName: _accountNameController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (!isAuthenticated) {
      AppNotice.error('Invalid account name or password.');
      return;
    }
    Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront, size: 72),
                      const SizedBox(height: 16),
                      Text('POS & Remittance',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      const Text('Sign in to continue'),
                      const SizedBox(height: 32),
                      TextFormField(
                          controller: _accountNameController,
                          decoration: const InputDecoration(
                              labelText: 'Account name',
                              border: OutlineInputBorder()),
                          validator: _validateAccountName),
                      const SizedBox(height: 16),
                      TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword))),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password.'
                              : null),
                      const SizedBox(height: 24),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: _isLoading ? null : _signIn,
                              child: _isLoading
                                  ? const CircularProgressIndicator()
                                  : const Text('Sign in'))),
                    ]),
              )),
        ))),
      );

  String? _validateAccountName(String? value) {
    final accountName = value?.trim() ?? '';
    if (accountName.isEmpty) return 'Enter your account name.';
    if (accountName.contains(' ')) {
      return 'Account name must not contain spaces.';
    }
    return null;
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
