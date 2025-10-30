import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/backup_service.dart';
import '../services/file_manager_service.dart';
import '../services/document_service.dart';

class BackupDialog extends StatefulWidget {
  const BackupDialog({super.key});

  @override
  State<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends State<BackupDialog> {

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Backup & Restore'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Pilih tindakan:'),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.backup),
                label: const Text('Backup'),
                onPressed: () => _startBackup(context),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('Restore'),
                onPressed: () => _startRestore(context),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Tutup'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }



  Future<void> _startBackup(BuildContext context) async {
    final docService = Provider.of<DocumentService>(context, listen: false);
    final fileManager = Provider.of<FileManagerService>(context, listen: false);
    
    // Buat instance BackupService
    final backupService = BackupService(fileManager, context);
    
    // Tampilkan loading dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Mempersiapkan Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Mohon tunggu...'),
          ],
        ),
      ),
    );
    
    try {
      // Lakukan backup
      final result = await backupService.createBackup(docService.docs);
      
      // Tutup dialog loading
      Navigator.of(context).pop();
      
      // Tampilkan hasil
      if (!mounted) return;
      
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result.success ? 'Backup Berhasil' : 'Backup Gagal'),
          content: Text(result.message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close progress dialog
      
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Gagal melakukan backup: $e'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }



  Future<void> _startRestore(BuildContext context) async {
    final fileManager = Provider.of<FileManagerService>(context, listen: false);
    
    // Buat instance BackupService
    final backupService = BackupService(fileManager, context);
    
    // Tampilkan loading dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text('Mempersiapkan Restore'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Mohon tunggu...'),
          ],
        ),
      ),
    );
    
    try {
      // Lakukan restore
      final result = await backupService.restoreFromBackup();
      
      // Tutup dialog loading
      Navigator.of(context).pop();
      
      // Tampilkan hasil
      if (!mounted) return;
      
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result.success ? 'Restore Berhasil' : 'Restore Gagal'),
          content: Text(result.message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      
    } catch (e) {
      // Tutup dialog loading
      Navigator.of(context).pop();
      
      // Tampilkan error
      if (!mounted) return;
      
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Terjadi kesalahan: $e'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
  }
}