import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

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
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => HomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: Duration(milliseconds: 600),
          ),
        );
      } else {
        setState(() => _error = 'Invalid username or password');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Login failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showRecoveryDialog() {
    final recoveryCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    var error = '';
    var loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.vpn_key,
                  color: Color(0xFF00D4AA),
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Account Recovery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Enter your recovery key to reset password',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                TextField(
                  controller: recoveryCtrl,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Recovery Key',
                    labelStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.vpn_key, color: Color(0xFF00D4AA)),
                    filled: true,
                    fillColor: Color(0xFF111111),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorText: error.isNotEmpty ? error : null,
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: true,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.lock, color: Color(0xFF00D4AA)),
                    filled: true,
                    fillColor: Color(0xFF111111),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (loading) ...[
                  SizedBox(height: 16),
                  CircularProgressIndicator(color: Color(0xFF00D4AA)),
                ],
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFF00D4AA),
                          side: BorderSide(color: Color(0xFF00D4AA)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00D4AA),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: loading ? null : () async {
                          if (recoveryCtrl.text.isEmpty || newPassCtrl.text.isEmpty) {
                            setState(() => error = 'Please fill all fields');
                            return;
                          }

                          setState(() {
                            loading = true;
                            error = '';
                          });

                          try {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            final success = await authService.recoverAccount(
                              recoveryCtrl.text.trim(),
                              newPassCtrl.text,
                            );

                            if (success) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Color(0xFF00D4AA),
                                  content: Text('Password reset successful'),
                                ),
                              );
                            } else {
                              setState(() => error = 'Invalid recovery key');
                            }
                          } catch (e) {
                            setState(() => error = 'Recovery failed: $e');
                          } finally {
                            setState(() => loading = false);
                          }
                        },
                        child: Text('Recover'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Spacer(flex: 2),
                // Header Section
                ScaleTransition(
                  scale: _animation,
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF00D4AA), Color(0xFF0095FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00D4AA).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.security_rounded,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 24),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Color(0xFF00D4AA), Color(0xFF0095FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          'JuMan',
                          style: TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Secure File Manager',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(flex: 1),
                // Login Form
                FadeTransition(
                  opacity: _animation,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF111111),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              TextField(
                                controller: _userCtrl,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  labelStyle: TextStyle(color: Colors.white54),
                                  prefixIcon: Icon(Icons.person, color: Color(0xFF00D4AA)),
                                  border: InputBorder.none,
                                ),
                              ),
                              Divider(color: Colors.white12, height: 1),
                              TextField(
                                controller: _passCtrl,
                                obscureText: _obscurePassword,
                                style: TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(color: Colors.white54),
                                  prefixIcon: Icon(Icons.lock, color: Color(0xFF00D4AA)),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _handleLogin(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFFF6B6B).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Color(0xFFFF6B6B).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Color(0xFFFF6B6B), size: 16),
                              SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: TextStyle(color: Color(0xFFFF6B6B)))),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF00D4AA),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: _loading ? null : _handleLogin,
                          child: _loading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextButton(
                        onPressed: _showRecoveryDialog,
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(color: Color(0xFF00D4AA)),
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(flex: 2),
                // Footer
                FadeTransition(
                  opacity: _animation,
                  child: Column(
                    children: [
                      Text(
                        'Default Credentials',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Username: admin • Password: 123',
                        style: TextStyle(color: Color(0xFF00D4AA), fontSize: 12),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'All data stored locally • Military-grade encryption',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}