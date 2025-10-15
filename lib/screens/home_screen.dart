
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/file_manager_service.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import '../models/document.dart';
import 'dart:io';
import 'add_files_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late FileManagerService fm;

  @override
  void initState() {
    super.initState();
    fm = FileManagerService(context);
    Provider.of<DocumentService>(context, listen: false).load();
  }

  @override
  Widget build(BuildContext context) {
    final docs = Provider.of<DocumentService>(context).docs;
    final auth = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('LockVerse'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Encrypted Documents', style: Theme.of(context).textTheme.headlineSmall),
              FloatingActionButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => AddFilesScreen())); Provider.of<DocumentService>(context, listen: false).load(); }, child: Icon(Icons.add)),
            ]),
            SizedBox(height: 12),
            Expanded(child: docs.isEmpty ? Center(child: Text('No documents yet')) : ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) => Card(
                color: Color(0xFF111111),
                margin: EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(Icons.insert_drive_file, color: Colors.tealAccent),
                  title: Text(docs[i].name),
                  subtitle: Text('Version ${docs[i].version} • ${docs[i].createdAt.toLocal().toString().split(" ")[0]}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      onPressed: () async {
                        await fm.openFile(docs[i]);
                      },
                      icon: Icon(Icons.open_in_new),
                    ),
                    IconButton(
                      onPressed: () async {
                        // Show encryption log and metadata dialog
                        final docService = Provider.of<DocumentService>(context, listen: false);
                        final activities = await docService.getDocumentActivity(docs[i].id);
                        showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Document Info'),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Name: ${docs[i].name}'),
                                  Text('Path: ${docs[i].path}'),
                                  Text('Version: ${docs[i].version}'),
                                  SizedBox(height: 12),
                                  Text('Activity Log:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ...activities.map((a) => Text('- ${a['action']} @ ${a['timestamp']}')),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
                            ],
                          ),
                        );
                      },
                      icon: Icon(Icons.list),
                      tooltip: 'Log',
                    ),
                    PopupMenuButton(
                      icon: Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete),
                            title: Text('Delete'),
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'delete') {
                          final docService = Provider.of<DocumentService>(context, listen: false);
                          try {
                            final tombstone = await docService.deleteDocumentWithTrash(docs[i].id, fm);
                            if (tombstone != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Document deleted'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () async {
                                      await docService.restoreDocument(tombstone, fm);
                                    },
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                          }
                        }
                      },
                    ),
                  ]),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
