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

  // FIX: Hanya satu method encryptBytes
  static Map<String, String> encryptBytes(Uint8List plainBytes, Uint8List keyBytes) {
    // Validasi dan fix key length - PERBAIKAN
    final validKey = _ensureAes256Key(keyBytes);
    
    final key = enc.Key(validKey);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: null));
    
    // Add PKCS7 padding manually
    final blockSize = 16;
    final padLength = blockSize - (plainBytes.length % blockSize);
    final padded = Uint8List(plainBytes.length + padLength);
    padded.setAll(0, plainBytes);
    padded.fillRange(plainBytes.length, padded.length, padLength);
    
    final encrypted = encrypter.encryptBytes(padded, iv: iv);
    return {
      'cipher': encrypted.base64,
      'iv': iv.base64,
    };
  }

  // FIX: Hanya satu method decryptBytes
  static Uint8List decryptBytes(String base64Cipher, String base64Iv, Uint8List keyBytes) {
    try {
      // Validasi dan fix key length - PERBAIKAN
      final validKey = _ensureAes256Key(keyBytes);
      
      final key = enc.Key(validKey);
      final iv = enc.IV.fromBase64(base64Iv);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc, padding: null));
      final decrypted = encrypter.decryptBytes(enc.Encrypted.fromBase64(base64Cipher), iv: iv);
      
      // Remove PKCS7 padding dengan error handling yang lebih baik
      if (decrypted.isEmpty) {
        throw Exception('Decrypted data is empty');
      }
      
      final padLength = decrypted.last;
      
      // Validasi padding length
      if (padLength < 1 || padLength > 16) {
        print('Warning: Invalid padding length $padLength, returning raw data');
        return Uint8List.fromList(decrypted);
      }
      
      // Validasi semua byte padding
      for (var i = decrypted.length - padLength; i < decrypted.length; i++) {
        if (decrypted[i] != padLength) {
          print('Warning: Invalid padding at position $i, expected $padLength got ${decrypted[i]}');
          return Uint8List.fromList(decrypted);
        }
      }
      
      return Uint8List.fromList(decrypted.sublist(0, decrypted.length - padLength));
    } catch (e) {
      print('Decryption error: $e');
      rethrow;
    }
  }

  // FIX: Method helper untuk memastikan key 32 bytes
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