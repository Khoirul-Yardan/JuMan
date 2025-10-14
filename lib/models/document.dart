
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
    id: map['id'],
    name: map['name'],
    path: map['path'],
    wrappedKey: map['wrapped_key'],
    iv: map['iv'],
    version: map['version'],
    createdAt: DateTime.parse(map['created_at']),
  );
}
