import 'package:flutter/material.dart';
import 'package:thefaithapp_auth/thefaithapp_auth.dart';

const clientKey = String.fromEnvironment('TFA_CLIENT_KEY');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PackageExample());
}

class PackageExample extends StatefulWidget {
  const PackageExample({super.key});

  @override
  State<PackageExample> createState() => _PackageExampleState();
}

class _PackageExampleState extends State<PackageExample> {
  TheFaithAppAuth? _auth;
  String _message = 'Add TFA_CLIENT_KEY to test hosted sign-in.';

  @override
  void initState() {
    super.initState();
    if (clientKey.isNotEmpty) {
      _auth = TheFaithAppAuth(apiKey: clientKey);
      _message = 'Ready to sign in.';
    }
  }

  Future<void> _signIn() async {
    try {
      final session = await _auth!.signIn();
      if (mounted) setState(() => _message = 'Hello ${session.member.name}');
    } on TheFaithAuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    }
  }

  @override
  void dispose() {
    _auth?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('TheFaithApp Auth')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_message),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _auth == null ? null : _signIn,
                child: const Text('Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
