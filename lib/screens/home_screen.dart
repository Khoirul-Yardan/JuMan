import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_manager_service.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import '../models/document.dart';
import 'dart:io';
import 'add_files_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'vault_debug_screen.dart'; // IMPORT INI
import '../services/backup_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late FileManagerService fm;
  late AnimationController _animationController;
  late Animation<double> _fabAnimation;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    fm = FileManagerService(context);
    Provider.of<DocumentService>(context, listen: false).load();
    
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Method untuk mendapatkan total size semua file
  String _getTotalSize(List<Document> docs) {
    try {
      int totalBytes = 0;
      for (final doc in docs) {
        final file = File(doc.path);
        if (file.existsSync()) {
          totalBytes += file.lengthSync();
        }
      }
      
      if (totalBytes < 1024) return '${totalBytes} B';
      if (totalBytes < 1048576) return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
      if (totalBytes < 1073741824) return '${(totalBytes / 1048576).toStringAsFixed(1)} MB';
      return '${(totalBytes / 1073741824).toStringAsFixed(1)} GB';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Method untuk mendapatkan size file individual
  String _getFileSize(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final size = file.lengthSync();
        if (size < 1024) return '${size} B';
        if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
        if (size < 1073741824) return '${(size / 1048576).toStringAsFixed(1)} MB';
        return '${(size / 1073741824).toStringAsFixed(1)} GB';
      }
    } catch (e) {
      return 'Unknown';
    }
    return 'Unknown';
  }

  // Method untuk format tanggal
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  // Method untuk menangani aksi file
  void _handleFileAction(String action, Document doc) async {
    final docService = Provider.of<DocumentService>(context, listen: false);
    
    switch (action) {
      case 'open':
        try {
          await fm.openFile(doc);
          _showCustomDialog('Success', 'File opened successfully');
        } catch (e) {
          _showCustomDialog('Error', 'Failed to open file: $e', isError: true);
        }
        break;
        
      case 'export':
        try {
          final exportedPath = await fm.exportDecrypted(doc);
          if (exportedPath != null) {
            _showCustomDialog('Export Successful', 'File exported to: $exportedPath');
          }
        } catch (e) {
          _showCustomDialog('Export Failed', 'Failed to export file: $e', isError: true);
        }
        break;
        
      case 'info':
        final activities = await docService.getDocumentActivity(doc.id);
        showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info,
                    color: Color(0xFF00D4AA),
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'File Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF111111),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Name', doc.name),
                        _buildInfoRow('Size', _getFileSize(doc.path)),
                        _buildInfoRow('Version', '${doc.version}'),
                        _buildInfoRow('Created', _formatDate(doc.createdAt)),
                        _buildInfoRow('Path', doc.path),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  if (activities.isNotEmpty) ...[
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 100,
                      child: ListView.builder(
                        itemCount: activities.length,
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.history, color: Color(0xFF00D4AA), size: 16),
                            title: Text(
                              activity['action'] ?? '',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            subtitle: Text(
                              activity['timestamp'] ?? '',
                              style: TextStyle(color: Colors.white54, fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00D4AA),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Close'),
                  ),
                ],
              ),
            ),
          ),
        );
        break;
        
      case 'delete':
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.delete,
                    color: Color(0xFFFF6B6B),
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Delete File',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Are you sure you want to delete "${doc.name}"?',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
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
                          onPressed: () => Navigator.pop(context, false),
                          child: Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFFF6B6B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        
        if (result == true) {
          try {
            final tombstone = await docService.deleteDocumentWithTrash(doc.id, fm);
            if (tombstone != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Color(0xFF1A1A1A),
                  content: Text('File moved to trash'),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: Color(0xFF00D4AA),
                    onPressed: () async {
                      await docService.restoreDocument(tombstone, fm);
                    },
                  ),
                ),
              );
            }
          } catch (e) {
            _showCustomDialog('Error', 'Failed to delete file: $e', isError: true);
          }
        }
        break;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomDialog(String title, String message, {bool isError = false, String? actionText, VoidCallback? onAction}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle,
                color: isError ? Color(0xFFFF6B6B) : Color(0xFF00D4AA),
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Row(
                children: [
                  if (actionText != null) ...[
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
                        onPressed: onAction,
                        child: Text(actionText),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00D4AA),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text('OK'),
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PERBAIKAN: Method untuk backup dialog
  void _showBackupDialog(List<Document> docs) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.backup,
                color: Color(0xFF00D4AA),
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Backup & Restore',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Manage your encrypted file backups',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              if (docs.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF00D4AA),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      final backup = BackupService(fm);
                      final result = await backup.createBackup(docs, context);
                      _showCustomDialog(
                        result.success ? 'Backup Successful' : 'Backup Failed',
                        result.message,
                        isError: !result.success,
                      );
                    },
                    icon: Icon(Icons.backup),
                    label: Text('Create Backup'),
                  ),
                ),
                SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF00D4AA),
                    side: BorderSide(color: Color(0xFF00D4AA)),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final backup = BackupService(fm);
                    final docService = Provider.of<DocumentService>(context, listen: false);
                    
                    final result = await backup.restoreFromBackup(docService: docService);
                    if (result.success || (result.restoredCount ?? 0) > 0) {
                      docService.load();
                    }
                    _showCustomDialog(
                      result.success ? 'Restore Successful' : 'Restore Completed',
                      result.message,
                      isError: !result.success && (result.restoredCount == 0),
                    );
                  },
                  icon: Icon(Icons.restore),
                  label: Text('Restore from Backup'),
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(AuthService auth) {
    _showCustomDialog(
      'Logout',
      'Are you sure you want to logout?',
      isError: true,
      actionText: 'Logout',
      onAction: () async {
        Navigator.pop(context);
        await auth.logout();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = Provider.of<DocumentService>(context).docs;
    final auth = Provider.of<AuthService>(context);
    
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF00D4AA), Color(0xFF0095FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: IconButton(
              icon: Icon(Icons.security, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JuMan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              '${docs.length} encrypted files',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.backup, color: Colors.white70),
            tooltip: 'Backup & Restore',
            onPressed: () => _showBackupDialog(docs),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.white70),
            color: Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen()));
                  break;
                case 'debug':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VaultDebugScreen()));
                  break;
                case 'logout':
                  _showLogoutDialog(auth);
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: Color(0xFF00D4AA)),
                    SizedBox(width: 8),
                    Text('Settings', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'debug',
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Color(0xFF00D4AA)),
                    SizedBox(width: 8),
                    Text('Debug Vault', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Color(0xFFFF6B6B)),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Color(0xFFFF6B6B))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.folder,
                    value: docs.length.toString(),
                    label: 'Total Files',
                    color: Color(0xFF00D4AA),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.storage,
                    value: _getTotalSize(docs),
                    label: 'Total Size',
                    color: Color(0xFF0095FF),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Files Section
            Expanded(
              child: docs.isEmpty 
                ? _buildEmptyState()
                : _buildFilesList(docs),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddFilesScreen()),
            );
            Provider.of<DocumentService>(context, listen: false).load();
          },
          backgroundColor: Color(0xFF00D4AA),
          foregroundColor: Colors.black,
          child: Icon(Icons.add, size: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required String value, required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Color(0xFF111111),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open,
              size: 50,
              color: Colors.white38,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'No Encrypted Files',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Add files to secure them with\nmilitary-grade encryption',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00D4AA),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddFilesScreen()),
              );
              Provider.of<DocumentService>(context, listen: false).load();
            },
            icon: Icon(Icons.add),
            label: Text('Add Files'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilesList(List<Document> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            'Encrypted Files',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) => _buildFileItem(docs[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(Document doc) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00D4AA).withOpacity(0.3), Color(0xFF0095FF).withOpacity(0.3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.insert_drive_file, color: Color(0xFF00D4AA)),
        ),
        title: Text(
          doc.name,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_getFileSize(doc.path)} • ${_formatDate(doc.createdAt)}',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.white54),
          color: Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) => _handleFileAction(value, doc),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new, color: Color(0xFF00D4AA), size: 20),
                  SizedBox(width: 8),
                  Text('Open', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, color: Color(0xFF00D4AA), size: 20),
                  SizedBox(width: 8),
                  Text('Export', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info, color: Color(0xFF00D4AA), size: 20),
                  SizedBox(width: 8),
                  Text('Info', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Color(0xFFFF6B6B), size: 20),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _handleFileAction('open', doc),
      ),
    );
  }
}