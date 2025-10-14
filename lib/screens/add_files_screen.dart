
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/file_manager_service.dart';
import '../services/encryption_service.dart';
import '../services/key_manager.dart';
import '../services/document_service.dart';

/// Exception thrown when encryption or file operations fail
class EncryptionException implements Exception {
  final String message;
  EncryptionException(this.message);
  @override
  String toString() => message;
}

/// A screen that allows users to pick files and add them to the encrypted vault
class AddFilesScreen extends StatefulWidget {
  const AddFilesScreen({Key? key}) : super(key: key);

  @override
  _AddFilesScreenState createState() => _AddFilesScreenState();
}

/// The state for the AddFilesScreen widget
class _AddFilesScreenState extends State<AddFilesScreen> {
  /// Service for handling file operations
  late final FileManagerService _fm;
  
  /// Whether the screen is currently processing files
  bool _working = false;
  
  /// List of files picked by the user
  List<PlatformFile>? _pickedFiles;
  
  /// Service for managing document metadata
  final DocumentService _docService = DocumentService();
  
  /// Key manager instance for encryption operations
  final KeyManager _keyManager = KeyManager();
  
  /// Whether the widget is still mounted and can update state
  bool get _canUpdateState => mounted;

  /// Shows a snackbar message if the widget is mounted
  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.blue,
      ),
    );
  }

  /// Updates the working state if the widget is mounted
  void _setWorking(bool value) {
    if (!mounted) return;
    setState(() => _working = value);
  }

  /// Clears the picked files list if the widget is mounted
  void _clearPickedFiles() {
    if (!mounted) return;
    setState(() => _pickedFiles = null);
  }

  @override
  void initState() {
    super.initState();
    _fm = FileManagerService(context);
    _docService.init();
  }

  /// Encrypts and saves the picked files to the secure vault
  /// 
  /// This method:
  /// 1. Gets the master key and root key
  /// 2. Processes each file:
  ///    - Reads file bytes
  ///    - Generates a file-specific key
  ///    - Encrypts the file with the file key
  ///    - Wraps the file key with the root key
  ///    - Saves the encrypted file and metadata
  /// 3. Shows progress via snackbar messages
  /// 4. Handles errors for individual files and the overall process

  Future<void> _encryptAndSaveFiles() async {
    final files = _pickedFiles;
    if (files == null || files.isEmpty) return;
    
    _setWorking(true);
    
    try {
      final masterKey = await _keyManager.getMasterKey();
      if (masterKey == null) {
        throw EncryptionException('Master key not available - please log in again');
      }

      final rootKey = await _keyManager.unwrapRootWithMaster(masterKey);
      if (rootKey == null) {
        throw EncryptionException('Root key not available - please log in again');
      }

      int processedFiles = 0;
      final totalFiles = files.length;

      // Process each file
      for (final pickedFile in files) {
        if (!mounted) break;
        if (pickedFile.path == null) continue;

        try {
          final file = File(pickedFile.path!);
          if (!await file.exists()) {
            _showMessage('File not found: ${pickedFile.name}', error: true);
            continue;
          }

          final bytes = await file.readAsBytes();
          
          // Generate per-file key and encrypt
          final fileKey = EncryptionService.randomBytes(32);
          final encRes = EncryptionService.encryptBytes(
            Uint8List.fromList(bytes), 
            fileKey
          );
          
          // Wrap file key with root key
          final wrapped = EncryptionService.encryptBytes(fileKey, rootKey);
          if (!wrapped.containsKey('cipher') || !encRes.containsKey('iv')) {
            throw EncryptionException('Encryption failed - invalid response');
          }

          // Combine cipher and IV for storage
          final encryptedData = Uint8List.fromList([
            ...base64.decode(encRes['cipher']!),
            ...base64.decode(encRes['iv']!)
          ]);

          // Save encrypted file and metadata
          final savedPath = await _fm.saveEncryptedBlob(
            pickedFile.name,
            encryptedData
          );

          await _fm.createDocumentMeta(
            pickedFile.name,
            savedPath,
            wrapped['cipher']!,
            wrapped['iv']!
          );

          // Delete original file to prevent opening the plaintext
          try {
            await file.delete();
          } catch (e) {
            // If delete fails, log but continue
            print('Warning: could not delete original file ${pickedFile.path}: $e');
          }

          processedFiles++;
          _showMessage(
            'Encrypted ${processedFiles} of ${totalFiles} files',
            error: false
          );
        } catch (e) {
          _showMessage(
            'Error processing ${pickedFile.name}: ${e.toString()}',
            error: true
          );
          continue;
        }
      }

      // Reload document list and show final success message
      await _docService.load();
      
      _showMessage('Successfully encrypted $processedFiles files', error: false);
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Error: ${e.toString()}', error: true);
    } finally {
      _setWorking(false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Files'),
        actions: [
          if (_pickedFiles != null && !_working)
            IconButton(
              icon: Icon(Icons.delete_outline),
              onPressed: () => setState(() => _pickedFiles = null),
              tooltip: 'Clear selection',
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _working ? null : () async {
                try {
                  final result = await _fm.pickFiles();
                  if (result != null) {
                    setState(() => _pickedFiles = result);
                  }
                } catch (e) {
                  _showMessage('Error selecting files: ${e.toString()}', error: true);
                }
              },
              icon: Icon(Icons.add),
              label: Text('Select Files'),
            ),
            SizedBox(height: 16),
            if (_pickedFiles != null) ...[
              Text(
                'Selected Files',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _pickedFiles!.length,
                  itemBuilder: (context, index) {
                    final file = _pickedFiles![index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(Icons.insert_drive_file),
                        title: Text(file.name),
                        subtitle: Text(
                          'Size: ${(file.size / 1024).toStringAsFixed(1)} KB'
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _working ? null : _encryptAndSaveFiles,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: _working
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Encrypting...'),
                        ],
                      )
                    : Text(
                        'Encrypt & Save ${_pickedFiles!.length} file(s)',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
