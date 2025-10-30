import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../models/document.dart';
import 'file_manager_service.dart';
import 'document_service.dart';
import 'secure_file_format.dart';

class BackupService {
  final FileManagerService _fileManager;
  
  // Gunakan GlobalKey instead of BuildContext - PERBAIKAN
  BackupService(this._fileManager);

  /// Membuat backup ke folder yang dipilih user
  Future<BackupResult> createBackup(List<Document> documents, BuildContext context) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder untuk menyimpan backup',
      );

      if (selectedDirectory == null) {
        return BackupResult(
          success: false, 
          message: 'Backup dibatalkan: Tidak ada folder yang dipilih'
        );
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupDir = Directory(path.join(selectedDirectory, 'juman_backup_$timestamp'));
      await backupDir.create(recursive: true);

      // Backup metadata dokumen
      final metadata = {
        'backup_info': {
          'app_name': 'JuMan Secure File Manager',
          'version': '1.0.0',
          'timestamp': timestamp,
          'total_files': documents.length,
          'backup_type': 'full',
        },
        'documents': documents.map((doc) => doc.toBackupMap()).toList(),
      };

      final metadataFile = File(path.join(backupDir.path, 'metadata.json'));
      await metadataFile.writeAsString(json.encode(metadata));

      // Backup file terenkripsi
      int successCount = 0;
      List<String> failedFiles = [];

      for (final doc in documents) {
        try {
          final sourceFile = File(doc.path);
          if (!await sourceFile.exists()) {
            failedFiles.add('${doc.name} (file tidak ditemukan)');
            continue;
          }

          // Salin file terenkripsi dengan nama yang sama
          final backupPath = path.join(backupDir.path, path.basename(doc.path));
          await sourceFile.copy(backupPath);
          successCount++;
        } catch (e) {
          failedFiles.add('${doc.name} ($e)');
        }
      }

      // Buat file manifest
      final manifestContent = '''
JuMan Backup Manifest
=====================

Backup Created: ${DateTime.now().toString()}
Total Files: ${documents.length}
Successfully Backed Up: $successCount
Failed Files: ${failedFiles.length}

${failedFiles.isNotEmpty ? 'Failed Files:\n${failedFiles.map((f) => '  • $f').join('\n')}' : ''}

Backup Location: ${backupDir.path}
App Version: 1.0.0
Security Level: AES-256 Encryption

IMPORTANT:
• This backup contains encrypted files
• Restore only to the same JuMan installation
• Keep this backup secure
''';

      final manifestFile = File(path.join(backupDir.path, 'backup_manifest.txt'));
      await manifestFile.writeAsString(manifestContent);

      return BackupResult(
        success: true,
        message: '✅ Backup berhasil!\n$successCount dari ${documents.length} file tersimpan\nLokasi: ${backupDir.path}',
        backupPath: backupDir.path,
        fileCount: successCount
      );

    } catch (e) {
      return BackupResult(
        success: false,
        message: '❌ Gagal membuat backup: $e'
      );
    }
  }

  /// Memulihkan file dari backup yang dipilih - PERBAIKAN TANPA CONTEXT
  Future<RestoreResult> restoreFromBackup({DocumentService? docService}) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Pilih folder backup untuk dipulihkan',
      );

      if (selectedDirectory == null) {
        return RestoreResult(
          success: false,
          message: 'Restore dibatalkan: Tidak ada folder yang dipilih'
        );
      }

      final backupDir = Directory(selectedDirectory);
      if (!await backupDir.exists()) {
        return RestoreResult(
          success: false,
          message: 'Folder backup tidak ditemukan'
        );
      }

      // Baca metadata
      final metadataFile = File(path.join(backupDir.path, 'metadata.json'));
      if (!await metadataFile.exists()) {
        return RestoreResult(
          success: false,
          message: 'Folder yang dipilih bukan folder backup JuMan yang valid (metadata.json tidak ditemukan)'
        );
      }

      final metadataContent = await metadataFile.readAsString();
      final metadata = json.decode(metadataContent) as Map<String, dynamic>;
      final backupInfo = metadata['backup_info'] as Map<String, dynamic>;
      final documentsData = metadata['documents'] as List<dynamic>;

      // Validasi backup
      final appName = backupInfo['app_name'] as String?;
      if (appName != 'JuMan Secure File Manager') {
        return RestoreResult(
          success: false,
          message: 'Backup tidak valid: Bukan backup dari JuMan'
        );
      }

      int successCount = 0;
      int skippedCount = 0;
      List<String> failedFiles = [];

      // Cari file backup yang sesuai
      final backupFiles = await backupDir.list().where((entity) => entity is File).toList();
      
      print('Found ${backupFiles.length} files in backup directory');
      print('Metadata indicates ${documentsData.length} documents');

      // Restore setiap dokumen
      for (final docData in documentsData) {
        final docMap = docData as Map<String, dynamic>;
        final originalDoc = Document.fromBackupMap(docMap);
        
        try {
          // Cari file backup berdasarkan nama asli dari metadata
          final fileName = path.basename(originalDoc.path);
          File? backupFile;
          
          for (final file in backupFiles) {
            if (file is File && path.basename(file.path) == fileName) {
              backupFile = file;
              break;
            }
          }

          if (backupFile == null || !await backupFile.exists()) {
            print('Backup file not found: $fileName');
            failedFiles.add('${originalDoc.name} (file backup tidak ditemukan: $fileName)');
            continue;
          }

          // Cek apakah file sudah ada di vault - gunakan docService yang diberikan
          final existingDocs = docService?.docs.where((d) => d.name == originalDoc.name).toList() ?? [];
          if (existingDocs.isNotEmpty) {
            print('File already exists, skipping: ${originalDoc.name}');
            skippedCount++;
            continue;
          }

          // Baca file backup
          print('Reading backup file: ${backupFile.path}');
          final bytes = await backupFile.readAsBytes();
          
          if (bytes.isEmpty) {
            failedFiles.add('${originalDoc.name} (file backup kosong)');
            continue;
          }

          // Simpan ke vault dengan nama baru
          final savedPath = await _fileManager.saveEncryptedBlob(
            originalDoc.name,
            bytes
          );
          
          if (savedPath.isNotEmpty && docService != null) {
            final newDoc = Document(
              id: 0,
              name: originalDoc.name,
              path: savedPath,
              wrappedKey: originalDoc.wrappedKey,
              iv: originalDoc.iv,
              version: originalDoc.version,
              createdAt: DateTime.now(),
            );
            
            await docService.addDocument(newDoc);
            successCount++;
            print('Successfully restored: ${originalDoc.name}');
          } else {
            failedFiles.add('${originalDoc.name} (gagal menyimpan ke vault)');
          }
        } catch (e) {
          print('Error restoring ${originalDoc.name}: $e');
          failedFiles.add('${originalDoc.name} ($e)');
        }
        
        // Tambahkan delay kecil untuk menghindari race condition
        await Future.delayed(Duration(milliseconds: 100));
      }

      String message;
      if (successCount > 0) {
        message = '✅ Restore berhasil!\n$successCount file dipulihkan';
        if (skippedCount > 0) {
          message += '\n$skippedCount file dilewati (sudah ada)';
        }
        if (failedFiles.isNotEmpty) {
          message += '\n${failedFiles.length} file gagal';
        }
      } else {
        message = '❌ Tidak ada file yang bisa dipulihkan';
        if (skippedCount > 0) {
          message += '\n$skippedCount file sudah ada di vault';
        }
        if (failedFiles.isNotEmpty) {
          message += '\nGagal: ${failedFiles.join(", ")}';
        }
      }

      return RestoreResult(
        success: successCount > 0,
        message: message,
        restoredCount: successCount,
        skippedCount: skippedCount,
        failedFiles: failedFiles
      );

    } catch (e) {
      print('Restore process failed: $e');
      return RestoreResult(
        success: false,
        message: '❌ Gagal memulihkan backup: $e'
      );
    }
  }

  /// Cek apakah folder adalah backup yang valid
  Future<bool> isValidBackupFolder(String folderPath) async {
    try {
      final metadataFile = File(path.join(folderPath, 'metadata.json'));
      if (!await metadataFile.exists()) return false;
      
      final metadataContent = await metadataFile.readAsString();
      final metadata = json.decode(metadataContent) as Map<String, dynamic>;
      final backupInfo = metadata['backup_info'] as Map<String, dynamic>;
      
      return backupInfo['app_name'] == 'JuMan Secure File Manager';
    } catch (e) {
      return false;
    }
  }
}

class BackupResult {
  final bool success;
  final String message;
  final String? backupPath;
  final int? fileCount;

  BackupResult({
    required this.success,
    required this.message,
    this.backupPath,
    this.fileCount,
  });
}

class RestoreResult {
  final bool success;
  final String message;
  final int? restoredCount;
  final int? skippedCount;
  final List<String>? failedFiles;

  RestoreResult({
    required this.success,
    required this.message,
    this.restoredCount,
    this.skippedCount,
    this.failedFiles,
  });
}