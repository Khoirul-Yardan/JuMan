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
import '../services/secure_file_format.dart';

class FileManagerService {
  final BuildContext context;

  FileManagerService(this.context);

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/juman';
    await Directory(path).create(recursive: true);
    return path;
  }

  Future<String> getVaultPath() async {
    final path = await _localPath;
    final vaultDir = Directory('$path/vault');
    await vaultDir.create(recursive: true);
    return vaultDir.path;
  }

  Future<List<PlatformFile>?> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    return result?.files;
  }

  Future<String> saveEncryptedBlob(String filename, List<int> encryptedBytes) async {
    // Create secure storage directory
    final path = await _localPath;
    final vaultDir = Directory('$path/vault');
    await vaultDir.create(recursive: true);

    // Pack encrypted data with secure format
    final secureBytes = SecureFileFormat.packFile(encryptedBytes, filename);

    // Generate random filename for storage
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomId = base64Url.encode(List.generate(8, (_) => DateTime.now().microsecondsSinceEpoch % 256));
    final filePath = '${vaultDir.path}/$timestamp-$randomId.lckv';
    final file = File(filePath);
    
    await file.writeAsBytes(secureBytes);
    
    // On Windows, set hidden and system attributes
    if (Platform.isWindows) {
      try {
        final processResult = await Process.run('attrib', ['+H', '+S', file.path]);
        if (processResult.exitCode != 0) {
          print('Warning: Could not set file attributes with attrib: ${processResult.stderr}');
        }
      } catch (e) {
        print('Warning: Failed to set file attributes: $e');
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

  /// PERBAIKAN: Export file dengan handling error yang lebih baik
  Future<String?> exportDecrypted(Document doc) async {
    try {
      final file = File(doc.path);
      if (!await file.exists()) throw Exception('File not found');

      final km = KeyManager();
      final masterKey = await km.getMasterKey();
      if (masterKey == null) throw Exception('Master key not available');
      
      print('Master key obtained, length: ${masterKey.length}');
      
      final rootKey = await km.unwrapRootWithMaster(masterKey);
      if (rootKey == null) throw Exception('Root key not available');

      print('Root key obtained, length: ${rootKey.length}');

      // Decrypt the wrapped file key
      final wrappedCipher = doc.wrappedKey;
      final wrappedIv = doc.iv;
      
      print('Wrapped cipher length: ${wrappedCipher.length}');
      print('Wrapped IV length: ${wrappedIv.length}');
      
      final fileKey = EncryptionService.decryptBytes(wrappedCipher, wrappedIv, rootKey);
      print('File key decrypted, length: ${fileKey.length}');

      // Baca file terenkripsi
      final bytes = await file.readAsBytes();
      print('Encrypted file size: ${bytes.length} bytes');
      
      // PERBAIKAN: Gunakan unpackFile yang lebih robust
      final unpacked = SecureFileFormat.unpackFile(bytes);
      if (unpacked == null) {
        throw Exception('Failed to unpack file - invalid format');
      }
      
      final encryptedData = unpacked['data'] as List<int>;
      final originalName = unpacked['header']['originalName'] as String;
      
      print('Encrypted data size: ${encryptedData.length} bytes');
      print('Original filename: $originalName');
      
      // PERBAIKAN: Validasi panjang data sebelum decrypt
      if (encryptedData.length < 32) { // Minimal cipher + IV
        throw Exception('Encrypted data is too small or corrupted');
      }
      
      // Pisahkan cipher dan IV - PERBAIKAN: IV selalu 16 bytes di akhir
      final cipherData = encryptedData.sublist(0, encryptedData.length - 16);
      final ivData = encryptedData.sublist(encryptedData.length - 16);
      
      print('Cipher size: ${cipherData.length}, IV size: ${ivData.length}');
      
      // Dekripsi data
      final decrypted = EncryptionService.decryptBytes(
        base64.encode(cipherData),
        base64.encode(ivData),
        fileKey,
      );

      print('File decrypted successfully, size: ${decrypted.length} bytes');

      // Minta user memilih lokasi export
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Pilih lokasi ekspor file',
        fileName: originalName,
      );

      if (savePath != null) {
        await File(savePath).writeAsBytes(decrypted);
        print('File exported to: $savePath');
        return savePath;
      }
      
      return null;

    } catch (e) {
      print('Export error details: $e');
      rethrow;
    }
  }

/// PERBAIKAN: Method openFile dengan multiple fallback strategies
Future<void> openFile(Document doc) async {
  try {
    final file = File(doc.path);
    if (!await file.exists()) {
      throw Exception('File not found at path: ${doc.path}');
    }

    final docService = Provider.of<DocumentService>(context, listen: false);
    final existingDoc = await docService.getDocument(doc.id);
    
    if (existingDoc == null) {
      throw Exception('Document metadata not found');
    }

    // Dapatkan kunci
    final km = KeyManager();
    final masterKey = await km.getMasterKey();
    if (masterKey == null) throw Exception('Master key not available');
    
    final rootKey = await km.unwrapRootWithMaster(masterKey);
    if (rootKey == null) throw Exception('Root key not available');
    
    // Buat file temporary untuk viewing
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/${doc.name}');

    try {
      // Decrypt the wrapped file key
      final wrappedCipher = existingDoc.wrappedKey;
      final wrappedIv = existingDoc.iv;

      print('Unwrapping file key for: ${doc.name}');
      final fileKey = EncryptionService.decryptBytes(wrappedCipher, wrappedIv, rootKey);
      print('File key unwrapped, length: ${fileKey.length}');

      // Baca file terenkripsi
      final bytes = await file.readAsBytes();
      print('Encrypted file size: ${bytes.length} bytes');
      
      // Unpack file
      final unpacked = SecureFileFormat.unpackFile(bytes);
      if (unpacked == null) {
        throw Exception('Failed to unpack file - invalid format');
      }
      
      final encryptedData = unpacked['data'] as List<int>;
      final originalName = unpacked['header']['originalName'] as String;
      
      print('Encrypted data size: ${encryptedData.length} bytes');
      print('Original filename: $originalName');
      
      // PERBAIKAN: Multiple decryption strategies
      Uint8List decrypted;
      
      try {
        // Strategy 1: Standard approach (cipher + IV)
        if (encryptedData.length >= 32) {
          final cipherData = encryptedData.sublist(0, encryptedData.length - 16);
          final ivData = encryptedData.sublist(encryptedData.length - 16);
          
          print('Strategy 1 - Cipher size: ${cipherData.length}, IV size: ${ivData.length}');
          
          decrypted = EncryptionService.decryptBytes(
            base64.encode(cipherData),
            base64.encode(ivData),
            fileKey,
          );
        } else {
          throw Exception('Data too short for standard decryption');
        }
      } catch (e) {
        print('Strategy 1 failed: $e');
        
        // Strategy 2: Try different IV position
        print('Trying Strategy 2 - Alternative IV position');
        try {
          // Coba dengan IV di awal
          if (encryptedData.length >= 32) {
            final ivPart = encryptedData.sublist(0, 16);
            final cipherPart = encryptedData.sublist(16);
            
            decrypted = EncryptionService.decryptBytes(
              base64.encode(cipherPart),
              base64.encode(ivPart),
              fileKey,
            );
          } else {
            throw Exception('Data too short for alternative decryption');
          }
        } catch (e2) {
          print('Strategy 2 failed: $e2');
          throw Exception('All decryption strategies failed: $e, $e2');
        }
      }

      print('File decrypted successfully, size: ${decrypted.length} bytes');

      // Tulis ke file temporary
      await tempFile.writeAsBytes(decrypted);
      
      // Buka file dengan aplikasi external
      final result = await OpenFilex.open(tempFile.path);
      
      // Schedule cleanup setelah 5 menit
      Future.delayed(const Duration(minutes: 5), () async {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('Temporary file cleaned up: ${tempFile.path}');
          }
        } catch (e) {
          print('Error cleaning up temp file: $e');
        }
      });

      if (result.type != ResultType.done) {
        throw Exception('Failed to open file: ${result.message}');
      }
      
      // Log aktivitas sukses
      await docService.logActivity(doc.id, 'opened');
      
    } catch (decryptError) {
      // Clean up temp file jika ada error
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
    
  } catch (e) {
    print('Open file error: $e');
    
    _showErrorDialog(
      'Cannot Open File',
      'The file could not be opened.\n\nError: $e\n\nPlease try exporting the file instead.'
    );
    
    rethrow;
  }
}
      
  
  /// Helper untuk menampilkan dialog error
  void _showErrorDialog(String title, String message) {
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Export decrypted file back to a user-accessible location (Downloads)
  Future<String> exportDecryptedToDownloads(Document doc, Uint8List decryptedBytes) async {
    final downloads = await getDownloadsDirectory();
    if (downloads == null) throw Exception('Downloads directory not available');
    
    final file = File('${downloads.path}/${doc.name}');
    await file.writeAsBytes(decryptedBytes);
    return file.path;
  }

  /// Decrypt an encrypted vault file and return plaintext bytes - PERBAIKAN
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
    
    // PERBAIKAN: Gunakan unpackFile
    final unpacked = SecureFileFormat.unpackFile(bytes);
    if (unpacked == null) {
      throw Exception('Failed to unpack file - invalid format');
    }
    
    final encryptedData = unpacked['data'] as List<int>;
    
    // Validasi panjang
    if (encryptedData.length < 32) {
      throw Exception('Encrypted data is too small or corrupted');
    }
    
    final cipherData = encryptedData.sublist(0, encryptedData.length - 16);
    final ivData = encryptedData.sublist(encryptedData.length - 16);
    
    final decrypted = EncryptionService.decryptBytes(
      base64.encode(cipherData),
      base64.encode(ivData),
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