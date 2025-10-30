import 'dart:convert';

class Document {
  final int id;
  final String name;
  final String path;
  final String wrappedKey;
  final String iv;
  final int version;
  final DateTime createdAt;

  Document({
    required this.id,
    required this.name,
    required this.path,
    required this.wrappedKey,
    required this.iv,
    required this.version,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'wrappedKey': wrappedKey,
      'iv': iv,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toBackupMap() {
    return {
      'name': name,
      'path': path, // Original path for reference
      'wrappedKey': wrappedKey,
      'iv': iv,
      'version': version,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Document.fromMap(Map<String, dynamic> map) {
    return Document(
      id: map['id'] as int,
      name: map['name'] as String,
      path: map['path'] as String,
      wrappedKey: map['wrappedKey'] as String,
      iv: map['iv'] as String,
      version: map['version'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  factory Document.fromBackupMap(Map<String, dynamic> map) {
    return Document(
      id: 0, // Will be assigned new ID
      name: map['name'] as String,
      path: map['path'] as String, // Original path, will be updated
      wrappedKey: map['wrappedKey'] as String,
      iv: map['iv'] as String,
      version: map['version'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());
  factory Document.fromJson(String source) => Document.fromMap(json.decode(source));
}