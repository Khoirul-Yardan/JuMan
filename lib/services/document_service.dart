
import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../models/document.dart';
import 'file_manager_service.dart';

class DocumentService extends ChangeNotifier {
  List<Document> _docs = [];
  List<Document> get docs => List.unmodifiable(_docs);

  Future<void> init() async {
    await LocalDB.init();
    await load();
  }

  Future<void> load() async {
    _docs = await LocalDB.getAllDocuments();
    notifyListeners();
  }

  Future<void> addDocument(Document doc) async {
    await LocalDB.insertDocument(doc);
    await load();
  }

  Future<void> deleteDocument(int id) async {
    await LocalDB.deleteDocument(id);
    await load();
  }

  /// Delete but move file to trash so it can be restored within the app
  Future<Map<String, dynamic>?> deleteDocumentWithTrash(int id, FileManagerService fm) async {
    final doc = await getDocument(id);
    if (doc == null) return null;

    // Move file to trash
    final trashPath = await fm.moveToTrash(doc.path);

    // Remove DB record
    await LocalDB.deleteDocument(id);
    await load();

    // Return tombstone info for possible restore
    final tombstone = {
      'doc': doc,
      'trashPath': trashPath,
    };
    await logActivity(id, 'deleted (moved to trash)');
    return tombstone;
  }

  Future<void> restoreDocument(Map<String, dynamic> tombstone, FileManagerService fm) async {
    final Document doc = tombstone['doc'] as Document;
    final String trashPath = tombstone['trashPath'] as String;

    // Restore file to vault
    final restoredPath = await fm.restoreFromTrash(trashPath);

    // Reinsert into DB
    final newDoc = Document(
      id: 0,
      name: doc.name,
      path: restoredPath,
      wrappedKey: doc.wrappedKey,
      iv: doc.iv,
      version: doc.version,
      createdAt: DateTime.now(),
    );
    await addDocument(newDoc);
    await logActivity(newDoc.id, 'restored from trash');
  }

  Future<void> logActivity(int id, String action) async {
    await LocalDB.logActivity(id, action);
  }

  Future<Document?> getDocument(int id) async {
    return await LocalDB.getDocument(id);
  }

  Future<List<Map<String, dynamic>>> getDocumentActivity(int id) async {
    return await LocalDB.getActivity(id);
  }
}
