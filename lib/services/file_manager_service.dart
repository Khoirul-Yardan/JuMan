
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../services/encryption_service.dart';
import '../services/key_manager.dart';

class FileManagerService {
  final BuildContext context;

  FileManagerService(this.context);

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/lockverse';
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<List<PlatformFile>?> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    return result?.files;
  }

  Future<String> saveEncryptedBlob(String filename, List<int> bytes) async {
    // Create secure storage directory
    final path = await _localPath;
    final vaultDir = Directory('$path/vault');
    await vaultDir.create(recursive: true);

    // Save encrypted file with timestamp and hidden attribute
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '${vaultDir.path}/$timestamp-$filename.enc';
    final file = File(filePath);
    
    await file.writeAsBytes(bytes);
    
    // On Windows, set hidden attribute
    if (Platform.isWindows) {
      final result = await Process.run('attrib', ['+H', file.path]);
      if (result.exitCode != 0) {
        print('Warning: Could not hide file: ${result.stderr}');
      }
    }
    
    return file.path;
  }

  /// Move an encrypted file to the app's trash directory. Returns the trash path.
  Future<String> moveToTrash(String encryptedPath) async {
    final path = await _localPath;
    final trashDir = Directory('$path/trash');
    await trashDir.create(recursive: true);

    final f = File(encryptedPath);
    if (!await f.exists()) throw Exception('File not found');

    final newPath = '${trashDir.path}/${DateTime.now().millisecondsSinceEpoch}-${f.uri.pathSegments.last}';
    await f.rename(newPath);
    return newPath;
  }

  /// Restore a file from trash back to vault. Returns restored path.
  Future<String> restoreFromTrash(String trashPath) async {
    final path = await _localPath;
    final vaultDir = Directory('$path/vault');
    await vaultDir.create(recursive: true);

    final f = File(trashPath);
    if (!await f.exists()) throw Exception('Trash file not found');

    final newPath = '${vaultDir.path}/${DateTime.now().millisecondsSinceEpoch}-${f.uri.pathSegments.last}';
    await f.rename(newPath);
    return newPath;
  }

  Future<void> openFile(Document doc) async {
    try {
      final file = File(doc.path);
      if (!await file.exists()) throw Exception('File not found');

      final docService = Provider.of<DocumentService>(context, listen: false);
      final existingDoc = await docService.getDocument(doc.id);
      
      if (existingDoc != null) {
        // File already in vault, just decrypt and open
        final km = KeyManager();
        final masterKey = await km.getMasterKey();
        if (masterKey == null) throw Exception('Master key not available');
        
        final rootKey = await km.unwrapRootWithMaster(masterKey);
        if (rootKey == null) throw Exception('Root key not available');
        
        // Create a temporary file for viewing
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/${doc.name}');

          // Decrypt the wrapped file key first (stored in DB as base64)
          final wrappedCipher = existingDoc.wrappedKey;
          final wrappedIv = existingDoc.iv;

          // Unwrap to obtain the per-file symmetric key
          late Uint8List fileKey;
          try {
            fileKey = EncryptionService.decryptBytes(wrappedCipher, wrappedIv, rootKey);
          } catch (e) {
            throw Exception('Failed to unwrap file key: $e');
          }

          // Decrypt the file contents using the unwrapped file key
          final bytes = await file.readAsBytes();
          if (bytes.length < 16) throw Exception('Encrypted file is too small or corrupted');
          final cipher = bytes.sublist(0, bytes.length - 16);
          final iv = bytes.sublist(bytes.length - 16);
          final decrypted = EncryptionService.decryptBytes(
            base64.encode(cipher),
            base64.encode(iv),
            fileKey,
          );
      
      // Write to temp and open
      await tempFile.writeAsBytes(decrypted);
      final result = await OpenFilex.open(tempFile.path);
      
      // Schedule cleanup
      Future.delayed(const Duration(minutes: 5), () {
        tempFile.delete().catchError((error) => file); // Return file to satisfy type requirement
      });

      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
      return;
    }} catch (e) {
      String message = 'Error opening file: $e';
      if (e.toString().contains('path')) {
        message = 'File not found or cannot be accessed';
        // Offer user to restore/export decrypted copy if possible
  // final docService = Provider.of<DocumentService>(context, listen: false);
        // Show a dialog prompting user to restore the file back to Downloads as plaintext
        showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('File missing'),
            content: Text('Encrypted file is missing from vault. You can try to export a decrypted copy if you have a backup of the encrypted blob. Do you want to attempt export?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
              ElevatedButton(onPressed: () async {
                Navigator.pop(context);
                // Attempt to export: if file not found in vault, nothing to do — just notify
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No encrypted blob available to export')));
              }, child: Text('OK')),
            ],
          ),
        );
      } else if (e.toString().contains('key')) {
        message = 'Cannot decrypt file - encryption key not available';
      } else if (e.toString().contains('decrypt')) {
        message = 'File decryption failed - file may be corrupted';
      }
      print(message);
      rethrow;
    }
  }

  /// Export decrypted file back to a user-accessible location (Downloads)
  Future<String> exportDecryptedToDownloads(Document doc, Uint8List decryptedBytes) async {
    final downloads = await getDownloadsDirectory();
    final file = File('${downloads!.path}/${doc.name}');
    await file.writeAsBytes(decryptedBytes);
    return file.path;
  }

  /// Decrypt an encrypted vault file and return plaintext bytes
  Future<Uint8List> decryptFileToBytes(Document doc) async {
    final file = File(doc.path);
    if (!await file.exists()) throw Exception('File not found');

    final km = KeyManager();
    final masterKey = await km.getMasterKey();
    if (masterKey == null) throw Exception('Master key not available');
    final rootKey = await km.unwrapRootWithMaster(masterKey);
    if (rootKey == null) throw Exception('Root key not available');

    final wrappedCipher = doc.wrappedKey;
    final wrappedIv = doc.iv;
    final fileKey = EncryptionService.decryptBytes(wrappedCipher, wrappedIv, rootKey);

    final bytes = await file.readAsBytes();
    if (bytes.length < 16) throw Exception('Encrypted file is too small or corrupted');
    final cipher = bytes.sublist(0, bytes.length - 16);
    final iv = bytes.sublist(bytes.length - 16);
    final decrypted = EncryptionService.decryptBytes(
      base64.encode(cipher),
      base64.encode(iv),
      fileKey,
    );
    return decrypted;
  }

  Future<void> createDocumentMeta(String name, String path, String wrappedKey, String iv) async {
    final doc = Document(
      id: 0,
      name: name,
      path: path,
      wrappedKey: wrappedKey,
      iv: iv,
      version: 1,
      createdAt: DateTime.now(),
    );

    await Provider.of<DocumentService>(context, listen: false).addDocument(doc);
  }
}
