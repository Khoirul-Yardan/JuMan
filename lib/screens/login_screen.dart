import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _handleLogin() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.authenticate(_userCtrl.text.trim(), _passCtrl.text);
      
      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        setState(() => _error = 'Invalid credentials');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login to LockVerse')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('How LockVerse works'),
                      content: SingleChildScrollView(
                        child: Text('LockVerse encrypts each file with a random per-file key. That key is encrypted with your root key, which is itself protected by your master password. Files are stored encrypted in the app vault. When opening, the app unwraps the file key and decrypts to a temporary file which is opened by your OS default app.'),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'))],
                    ),
                  );
                },
                child: Text('How it works'),
              ),
            ),
            TextField(
              controller: _userCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(
                labelText: 'Master Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              onSubmitted: (_) => _handleLogin(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _handleLogin,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Login'),
            ),
            TextButton(
              child: Text('Forgot Password?'),
              onPressed: () {
                // Show recovery dialog
                  showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Recover Account'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            labelText: 'Recovery Code',
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        child: Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      ElevatedButton(
                        child: Text('Recover'),
                        onPressed: () {
                          // Implement recovery logic
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}