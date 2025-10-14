
import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final auth = Provider.of<AuthService>(context, listen: false);
    final isLoggedIn = await auth.checkLoginStatus();
    
    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
      return;
    }
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/splash.json',
              width: 200,
              height: 200,
            ),
            const SizedBox(height: 20),
            Text(
              'LockVerse',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Secure File Storage',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}