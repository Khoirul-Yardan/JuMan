import 'dart:convert';
import 'dart:typed_data';

class SecureFileFormat {
  static const String magicBytes = 'LCKV';
  static const int version = 1;
  
  static List<int> packFile(List<int> encryptedData, String originalName) {
    final header = {
      'magic': magicBytes,
      'version': version,
      'timestamp': DateTime.now().toIso8601String(),
      'originalName': originalName,
    };
    
    final headerBytes = utf8.encode(json.encode(header));
    final headerLength = headerBytes.length;
    
    final result = ByteData(4 + headerLength + encryptedData.length);
    
    result.setUint32(0, headerLength, Endian.big);
    
    for (var i = 0; i < headerLength; i++) {
      result.setUint8(4 + i, headerBytes[i]);
    }
    
    for (var i = 0; i < encryptedData.length; i++) {
      result.setUint8(4 + headerLength + i, encryptedData[i]);
    }
    
    return result.buffer.asUint8List();
  }
  
  static Map<String, dynamic> unpackFile(List<int> data) {
    final buffer = ByteData.sublistView(Uint8List.fromList(data));
    
    final headerLength = buffer.getUint32(0, Endian.big);
    
    final headerBytes = data.sublist(4, 4 + headerLength);
    final header = json.decode(utf8.decode(headerBytes));
    
    if (header['magic'] != magicBytes) {
      throw FormatException('Invalid file format: not a LockVerse encrypted file');
    }
    
    if (header['version'] != version) {
      throw FormatException('Unsupported file format version: ${header['version']}');
    }
    
    final encryptedData = data.sublist(4 + headerLength);
    
    return {
      'header': header,
      'data': encryptedData,
    };
  }
  
  static bool isValidFormat(List<int> data) {
    try {
      unpackFile(data);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  static String? getOriginalName(List<int> data) {
    try {
      final unpacked = unpackFile(data);
      return unpacked['header']['originalName'] as String?;
    } catch (e) {
      return null;
    }
  }
}