
enum DocumentType { docx, xlsx, pdf, txt, unknown }

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

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'path': path,
    'wrapped_key': wrappedKey,
    'iv': iv,
    'version': version,
    'created_at': createdAt.toIso8601String(),
  };

  static Document fromMap(Map<String, dynamic> map) => Document(
    id: map['id'] is int ? map['id'] as int : (map['id'] as num).toInt(),
    name: map['name'] as String,
    path: map['path'] as String,
    wrappedKey: map['wrapped_key'] as String,
    iv: map['iv'] as String,
    version: map['version'] is int ? map['version'] as int : (map['version'] as num).toInt(),
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
