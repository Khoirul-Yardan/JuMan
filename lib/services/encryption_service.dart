import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  static const _charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?';
  
  static String generateSecurePassword({int length = 16}) {
    final random = Random.secure();
    return List.generate(length, (_) => _charset[random.nextInt(_charset.length)]).join();
  }

  static Uint8List pbkdf2(String password, Uint8List salt, int iterations, int length) {
    final bytes = utf8.encode(password);
    final output = List<int>.filled(length, 0);
    var block = 1;
    var pos = 0;

    while (pos < length) {
      final hmac = Hmac(sha256, bytes);
      var digest = Uint8List.fromList(salt + _intToBytes(block));
      
      var hash = hmac.convert(digest).bytes;
      var intermediate = List<int>.from(hash);
      
      for (var i = 1; i < iterations; i++) {
        hash = hmac.convert(hash).bytes;
        for (var j = 0; j < hash.length; j++) {
          intermediate[j] ^= hash[j];
        }
      }
      
      final remaining = length - pos;
      final blockLength = remaining > 32 ? 32 : remaining;
      output.setRange(pos, pos + blockLength, intermediate);
      pos += blockLength;
      block++;
    }

    return Uint8List.fromList(output);
  }

  static Uint8List _intToBytes(int value) {
    final buffer = Uint8List(4);
    buffer[0] = (value >> 24) & 0xFF;
    buffer[1] = (value >> 16) & 0xFF;
    buffer[2] = (value >> 8) & 0xFF;
    buffer[3] = value & 0xFF;
    return buffer;
  }

  static Uint8List randomBytes(int len) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(len, (_) => rnd.nextInt(256)));
  }

  static Map<String, String> encryptBytes(Uint8List plainBytes, Uint8List keyBytes) {
    // Validasi dan fix key length
    final validKey = _ensureAes256Key(keyBytes);
    
    final key = enc.Key(validKey);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
    
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);
    return {
      'cipher': encrypted.base64,
      'iv': iv.base64,
    };
  }

  // PERBAIKAN: Fix return type Uint8List
  static Uint8List decryptBytes(String base64Cipher, String base64Iv, Uint8List keyBytes) {
    try {
      // Validasi dan fix key length
      final validKey = _ensureAes256Key(keyBytes);
      
      final key = enc.Key(validKey);
      final iv = enc.IV.fromBase64(base64Iv);
      
      // Gunakan padding PKCS7
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: 'PKCS7'));
      
      final encrypted = enc.Encrypted.fromBase64(base64Cipher);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      
      // PERBAIKAN: Convert List<int> to Uint8List
      return Uint8List.fromList(decrypted);
      
    } catch (e) {
      print('Decryption error: $e');
      
      // FALLBACK: Coba tanpa padding manual
      try {
        print('Trying fallback decryption...');
        return _decryptBytesFallback(base64Cipher, base64Iv, keyBytes);
      } catch (fallbackError) {
        print('Fallback decryption also failed: $fallbackError');
        rethrow;
      }
    }
  }

  // FALLBACK method untuk handle berbagai format - PERBAIKAN: Fix return type
  static Uint8List _decryptBytesFallback(String base64Cipher, String base64Iv, Uint8List keyBytes) {
    final validKey = _ensureAes256Key(keyBytes);
    final key = enc.Key(validKey);
    final iv = enc.IV.fromBase64(base64Iv);
    
    // Coba berbagai padding options
    final paddingOptions = ['PKCS7', null];
    
    for (final padding in paddingOptions) {
      try {
        print('Trying padding: $padding');
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: padding));
        final encrypted = enc.Encrypted.fromBase64(base64Cipher);
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        
        print('Success with padding: $padding, decrypted size: ${decrypted.length}');
        
        // PERBAIKAN: Convert List<int> to Uint8List
        return Uint8List.fromList(decrypted);
      } catch (e) {
        print('Failed with padding $padding: $e');
        continue;
      }
    }
    
    throw Exception('All decryption attempts failed');
  }

  // Method helper untuk memastikan key 32 bytes
  static Uint8List _ensureAes256Key(Uint8List key) {
    if (key.length == 32) {
      return key;
    }
    
    print('Fixing AES-256 key length from ${key.length} to 32 bytes');
    
    if (key.length > 32) {
      // Ambil 32 bytes pertama
      return key.sublist(0, 32);
    } else {
      // Gunakan hash untuk mendapatkan 32 bytes yang konsisten
      final hash = sha256.convert(key);
      return Uint8List.fromList(hash.bytes);
    }
  }

  static String hmacBase64(String data, String key) {
    final hmac = Hmac(sha256, utf8.encode(key));
    return base64.encode(hmac.convert(utf8.encode(data)).bytes);
  }
}