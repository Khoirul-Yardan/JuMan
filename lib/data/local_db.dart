
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/document.dart';

class LocalDB {
  static Database? _db;
  
  static Future<LocalDB> init() async {
    await getDb();
    return LocalDB();
  }

  static Future<Database> getDb() async {
    if (_db != null) return _db!;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'lockverse_v2_full.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            path TEXT NOT NULL,
            wrapped_key TEXT NOT NULL,
            iv TEXT NOT NULL,
            version INTEGER NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE activity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            doc_id INTEGER,
            action TEXT,
            timestamp TEXT,
            FOREIGN KEY (doc_id) REFERENCES documents (id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Drop old tables if they exist
          await db.execute('DROP TABLE IF EXISTS documents');
          await db.execute('DROP TABLE IF EXISTS activity_log');
          
          // Create new tables
          await db.execute('''
            CREATE TABLE documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              path TEXT NOT NULL,
              wrapped_key TEXT NOT NULL,
              iv TEXT NOT NULL,
              version INTEGER NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE activity_log (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              doc_id INTEGER,
              action TEXT,
              timestamp TEXT,
              FOREIGN KEY (doc_id) REFERENCES documents (id)
            )
          ''');
        }
      }
    );
    return _db!;
  }

  static Future<void> insertDocument(Document doc) async {
    final db = await getDb();
    await db.insert('documents', {
      'name': doc.name,
      'path': doc.path,
      'wrapped_key': doc.wrappedKey,
      'iv': doc.iv,
      'version': doc.version,
      'created_at': doc.createdAt.toIso8601String()
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<Document>> getAllDocuments() async {
    final db = await getDb();
    final rows = await db.query('documents', orderBy: 'created_at DESC');
    return rows.map((r) => Document(
      id: r['id'] as int,
      name: r['name'] as String,
      path: r['path'] as String,
      wrappedKey: r['wrapped_key'] as String,
      iv: r['iv'] as String,
      version: r['version'] as int,
      createdAt: DateTime.parse(r['created_at'] as String),
    )).toList();
  }

  static Future<Document?> getDocument(int id) async {
    final db = await getDb();
    final rows = await db.query('documents', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    
    final r = rows.first;
    return Document(
      id: r['id'] as int,
      name: r['name'] as String,
      path: r['path'] as String,
      wrappedKey: r['wrapped_key'] as String,
      iv: r['iv'] as String,
      version: r['version'] as int,
      createdAt: DateTime.parse(r['created_at'] as String),
    );
  }

  static Future<void> deleteDocument(int id) async {
    final db = await getDb();
    await db.transaction((txn) async {
      await txn.delete('activity_log', where: 'doc_id = ?', whereArgs: [id]);
      await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> logActivity(int docId, String action) async {
    final db = await getDb();
    await db.insert('activity_log', {
      'doc_id': docId,
      'action': action,
      'timestamp': DateTime.now().toIso8601String()
    });
  }

  static Future<List<Map<String,dynamic>>> getActivity(int docId) async {
    final db = await getDb();
    return await db.query(
      'activity_log',
      where: 'doc_id = ?',
      whereArgs: [docId],
      orderBy: 'timestamp DESC'
    );
  }
}
