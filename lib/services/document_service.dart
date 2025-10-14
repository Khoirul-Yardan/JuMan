
import 'package:flutter/material.dart';
import '../data/local_db.dart';
import '../models/document.dart';

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
