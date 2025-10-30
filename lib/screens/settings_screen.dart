import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPassCtrl = TextEditingController();
  final _newUserCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  String? _error;
  bool _loading = false;
  String? _recoveryKey;
  bool _showRecoveryKey = false;

  @override
  void initState() {
    super.initState();
    _loadRecoveryKey();
  }

  Future<void> _loadRecoveryKey() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    _recoveryKey = await authService.getRecoveryCode();
    setState(() {});
  }

  Future<void> _handleChangeCredentials() async {
    if (_loading) return;
    if (_currentPassCtrl.text.isEmpty || _newUserCtrl.text.isEmpty || _newPassCtrl.text.isEmpty) {
      setState(() => _error = 'Harap isi semua field');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.changeCredentials(
        _currentPassCtrl.text,
        _newUserCtrl.text,
        _newPassCtrl.text,
      );

      if (success) {
        _showSuccessDialog('Kredensial berhasil diperbarui');
        _currentPassCtrl.clear();
        _newUserCtrl.clear();
        _newPassCtrl.clear();
      } else {
        setState(() => _error = 'Gagal memperbarui kredensial');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Icon(Icons.check_circle, color: Color(0xFF4ECDC4), size: 48),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4ECDC4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newUserCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Color(0xFF111111),
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Recovery Key Card
            _buildSectionCard(
              title: 'Recovery Key',
              icon: Icons.vpn_key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_recoveryKey != null) ...[
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _showRecoveryKey ? _recoveryKey! : '•' * 20,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: _showRecoveryKey ? Color(0xFF4ECDC4) : Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              _showRecoveryKey ? Icons.visibility_off : Icons.visibility,
                              color: Color(0xFF4ECDC4),
                            ),
                            onPressed: () => setState(() => _showRecoveryKey = !_showRecoveryKey),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF4ECDC4).withOpacity(0.1),
                              foregroundColor: Color(0xFF4ECDC4),
                            ),
                            icon: Icon(Icons.copy),
                            label: Text('Copy Key'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _recoveryKey!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: Color(0xFF1E1E1E),
                                  content: Text('Recovery key disalin ke clipboard'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else
                    Center(child: CircularProgressIndicator(color: Color(0xFF4ECDC4))),
                  SizedBox(height: 8),
                  Text(
                    '⚠️ Simpan recovery key di tempat yang aman! Key ini diperlukan untuk memulihkan akun jika lupa password.',
                    style: TextStyle(color: Color(0xFFFFD93D), fontSize: 12),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // Change Credentials Card
            _buildSectionCard(
              title: 'Change Credentials',
              icon: Icons.security,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _currentPassCtrl,
                    label: 'Current Password',
                    icon: Icons.lock,
                    obscureText: true,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    controller: _newUserCtrl,
                    label: 'New Username',
                    icon: Icons.person,
                  ),
                  SizedBox(height: 12),
                  _buildTextField(
                    controller: _newPassCtrl,
                    label: 'New Password',
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  if (_error != null) ...[
                    SizedBox(height: 12),
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
                  SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4ECDC4),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _loading ? null : _handleChangeCredentials,
                    child: _loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text('Update Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Color(0xFF4ECDC4)),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Color(0xFF4ECDC4)),
        filled: true,
        fillColor: Colors.black26,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF4ECDC4)),
        ),
      ),
    );
  }
}