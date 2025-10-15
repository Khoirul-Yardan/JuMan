import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Welcome to LockVerse',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your secure file storage solution',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => OnboardingScreen()),
                ),
                child: const Text(
                  'Create New Account',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
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
            ],
          ),
        ),
      ),
    );
  }
}