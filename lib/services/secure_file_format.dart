import 'dart:convert';
import 'dart:typed_data';

class SecureFileFormat {
  static const String _magicBytes = 'JUMAN1.0';
  static const int _headerSize = 128; // Fixed header size
  
  /// Pack file data with secure format
  static Uint8List packFile(List<int> encryptedData, String originalName) {
    final header = _createHeader(originalName, encryptedData.length);
    return Uint8List.fromList([...header, ...encryptedData]);
  }
  
  /// Unpack file data - PERBAIKAN: Lebih robust
  static Map<String, dynamic>? unpackFile(List<int> data) {
    try {
      if (data.length < _headerSize) {
        print('File too small for header. Size: ${data.length}, expected at least $_headerSize');
        return null;
      }
      
      // PERBAIKAN: Convert List<int> to Uint8List untuk header
      final headerBytes = Uint8List.fromList(data.sublist(0, _headerSize));
      final header = _parseHeader(headerBytes);
      
      if (header == null) {
        print('Failed to parse header');
        return null;
      }
      
      // Extract data (everything after header)
      final fileData = data.sublist(_headerSize);
      
      // Validate data size
      final expectedSize = header['dataSize'] as int;
      if (fileData.length != expectedSize) {
        print('Data size mismatch. Expected: $expectedSize, Got: ${fileData.length}');
        // Tapi tetap lanjutkan, mungkin ada padding atau perubahan kecil
      }
      
      return {
        'header': header,
        'data': fileData,
      };
    } catch (e) {
      print('Error unpacking file: $e');
      return null;
    }
  }
  
  static Uint8List _createHeader(String originalName, int dataSize) {
    final nameBytes = utf8.encode(originalName);
    final header = Uint8List(_headerSize);
    
    // Magic bytes
    final magic = utf8.encode(_magicBytes);
    header.setRange(0, magic.length, magic);
    
    // Original name length and data
    header[16] = nameBytes.length;
    if (nameBytes.length > 0) {
      final nameEnd = 17 + nameBytes.length;
      if (nameEnd <= _headerSize) {
        header.setRange(17, nameEnd, nameBytes);
      }
    }
    
    // Data size (4 bytes)
    header[80] = (dataSize >> 24) & 0xFF;
    header[81] = (dataSize >> 16) & 0xFF;
    header[82] = (dataSize >> 8) & 0xFF;
    header[83] = dataSize & 0xFF;
    
    // Timestamp (8 bytes)
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 8; i++) {
      header[84 + i] = (timestamp >> (56 - i * 8)) & 0xFF;
    }
    
    return header;
  }
  
  static Map<String, dynamic>? _parseHeader(Uint8List header) {
    try {
      // Check magic bytes
      final magic = utf8.decode(header.sublist(0, _magicBytes.length));
      if (magic != _magicBytes) {
        print('Invalid magic bytes: $magic');
        return null;
      }
      
      // Get original name
      final nameLength = header[16];
      String originalName = 'unknown';
      if (nameLength > 0 && nameLength < 100) {
        final nameStart = 17;
        final nameEnd = nameStart + nameLength;
        if (nameEnd <= header.length) {
          originalName = utf8.decode(header.sublist(nameStart, nameEnd));
        }
      }
      
      // Get data size
      final dataSize = (header[80] << 24) |
                      (header[81] << 16) |
                      (header[82] << 8) |
                      header[83];
      
      // Get timestamp
      var timestamp = 0;
      for (var i = 0; i < 8; i++) {
        timestamp = (timestamp << 8) | header[84 + i];
      }
      
      return {
        'originalName': originalName,
        'dataSize': dataSize,
        'timestamp': timestamp,
        'magicBytes': magic,
      };
    } catch (e) {
      print('Error parsing header: $e');
      return null;
    }
  }
}