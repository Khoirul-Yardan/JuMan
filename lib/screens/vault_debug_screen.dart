import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VaultDebugScreen extends StatefulWidget {
  @override
  _VaultDebugScreenState createState() => _VaultDebugScreenState();
}

class _VaultDebugScreenState extends State<VaultDebugScreen> {
  List<FileSystemEntity> _vaultFiles = [];
  bool _loading = true;
  String _vaultPath = '';

  @override
  void initState() {
    super.initState();
    _loadVaultFiles();
  }

  Future<void> _loadVaultFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final vaultDir = Directory('${directory.path}/juman/vault');
      _vaultPath = vaultDir.path;
      
      if (await vaultDir.exists()) {
        final files = await vaultDir.list().toList();
        setState(() {
          _vaultFiles = files.whereType<File>().toList();
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading vault files: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _revealInExplorer() async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [_vaultPath]);
      }
    } catch (e) {
      print('Error revealing in explorer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Color(0xFF111111),
        title: Text('Vault Debug'),
        actions: [
          IconButton(
            icon: Icon(Icons.folder_open),
            onPressed: _revealInExplorer,
            tooltip: 'Open in Explorer',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadVaultFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: Color(0xFF111111),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vault Information',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Path: $_vaultPath',
                            style: TextStyle(
                              color: Colors.white54,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Total Files: ${_vaultFiles.length}',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Files in Vault:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: _vaultFiles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.white38),
                                SizedBox(height: 16),
                                Text(
                                  'No files found in vault',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _vaultFiles.length,
                            itemBuilder: (context, index) {
                              final file = _vaultFiles[index];
                              final stat = file.statSync();
                              return Card(
                                color: Color(0xFF111111),
                                margin: EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(Icons.insert_drive_file, color: Color(0xFF00D4AA)),
                                  title: Text(
                                    file.uri.pathSegments.last,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Size: ${_formatBytes(stat.size)} • Modified: ${_formatDate(stat.modified)}',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.day}/${date.month}/${date.year}';
  }
}