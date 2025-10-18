# Laporan Proyek PBO - LockVerse: Aplikasi Enkripsi File

## 1. Latar Belakang

### Alasan Pemilihan Judul Proyek
LockVerse dipilih sebagai proyek karena adanya kebutuhan mendesak akan aplikasi enkripsi file yang:
- Mudah digunakan oleh pengguna awam
- Menjamin keamanan data sensitif
- Berjalan di berbagai platform (Windows, Linux, macOS)
- Memiliki antarmuka yang intuitif
- Mendukung berbagai jenis file

### Urgensi dan Manfaat
1. Urgensi:
   - Meningkatnya kasus kebocoran data sensitif
   - Kebutuhan enkripsi file untuk work from home
   - Minimnya aplikasi enkripsi yang user-friendly
   - Perlunya proteksi dokumen pribadi dari akses tidak sah

2. Manfaat:
   - Melindungi privasi data pengguna
   - Memudahkan manajemen file terenkripsi
   - Mencegah akses tidak sah ke dokumen sensitif
   - Menyediakan cara aman berbagi file

## 2. Deskripsi Aplikasi

### Fungsi Utama
LockVerse adalah aplikasi enkripsi file yang memungkinkan pengguna untuk:
1. Mengenkripsi file dengan AES-256
2. Membuka file terenkripsi dengan aplikasi default
3. Mengelola file terenkripsi dalam vault
4. Mengekspor file kembali dalam bentuk tidak terenkripsi
5. Memulihkan akses dengan kunci pemulihan

### Fitur-fitur
1. Enkripsi File
   ```dart
   // Contoh kode dari add_files_screen.dart
   Future<void> encryptFile(File file) async {
     _addProgress('Membaca file...');
     final bytes = await file.readAsBytes();
     
     _addProgress('Mengenkripsi...');
     final fileKey = EncryptionService.randomBytes(32);
     final encrypted = EncryptionService.encryptBytes(bytes, fileKey);
     
     _addProgress('Menyimpan file terenkripsi...');
     final path = await _fileManager.saveEncryptedBlob(
       file.path.split(Platform.pathSeparator).last,
       encrypted
     );
   }
   ```

2. Manajemen Vault
   ```dart
   // Contoh dari file_manager_service.dart
   Future<String> moveToTrash(String encryptedPath) async {
     final path = await _localPath;
     final trashDir = Directory('$path/trash');
     await trashDir.create(recursive: true);
     
     final f = File(encryptedPath);
     final newPath = '${trashDir.path}/${DateTime.now().millisecondsSinceEpoch}-${f.uri.pathSegments.last}';
     await f.rename(newPath);
     return newPath;
   }
   ```

3. Sistem Pemulihan
   ```dart
   // Contoh dari key_manager.dart
   Future<bool> recoverRootWithRecoveryCode(String recoveryCode) async {
     final wrappedKey = await _storage.read(key: 'recovery_wrapped_root');
     if (wrappedKey == null) return false;
     
     final rootKey = EncryptionService.decryptBytes(
       wrappedKey,
       recoveryCode
     );
     await _storeRootKey(rootKey);
     return true;
   }
   ```

## 3. Desain Sistem

### Diagram dan Struktur
1. **Arsitektur MVC+S (Model-View-Controller+Service)**
   - Models: `Document`, `ActivityLog`
   - Views: `HomeScreen`, `AddFilesScreen`, `LoginScreen`
   - Services: `EncryptionService`, `FileManagerService`, `DocumentService`
   - Controllers: Provider state management

2. **Diagram Kelas Utama**
   ```
   Document
   ├── id: int
   ├── name: String 
   ├── path: String
   ├── wrappedKey: String
   ├── iv: String
   └── createdAt: DateTime

   FileManagerService
   ├── saveEncryptedBlob()
   ├── openFile()
   ├── moveToTrash()
   └── exportDecryptedToDownloads()

   EncryptionService
   ├── encryptBytes()
   ├── decryptBytes()
   ├── pbkdf2()
   └── randomBytes()
   ```

3. **Penerapan OOP**
   - **Inheritance**: Extending `StatefulWidget`/`State`
     ```dart
     class HomeScreen extends StatefulWidget {
       @override
       State<HomeScreen> createState() => _HomeScreenState();
     }
     ```
   
   - **Encapsulation**: Private fields/methods
     ```dart
     class KeyManager {
       final FlutterSecureStorage _storage;
       Future<String?> _getStoredMasterKey() async {
         return await _storage.read(key: 'master_key');
       }
     }
     ```
   
   - **Polymorphism**: Interface implementation
     ```dart
     abstract class StorageProvider {
       Future<void> save(String key, String value);
       Future<String?> read(String key);
     }

     class SecureStorageProvider implements StorageProvider {
       final _storage = FlutterSecureStorage();
       
       @override
       Future<void> save(String key, String value) async {
         await _storage.write(key: key, value: value);
       }
     }
     ```

### Perbandingan dengan Aplikasi Serupa

1. **VeraCrypt**
   - Kelebihan VeraCrypt:
     * Mendukung volume terenkripsi
     * Algoritma enkripsi yang lebih beragam
     * Sudah teruji waktu
   - Kelebihan LockVerse:
     * UI yang lebih modern dan intuitif
     * Integrasi dengan aplikasi default OS
     * Lebih ringan dan portabel
     * Fitur recovery key yang user-friendly

2. **7-Zip**
   - Kelebihan 7-Zip:
     * Mendukung kompresi
     * Lebih cepat untuk file besar
     * Open source dan gratis
   - Kelebihan LockVerse:
     * Fokus pada enkripsi (bukan kompresi)
     * UI yang lebih modern
     * Progress log untuk presentasi
     * Sistem vault terpusat

3. **Cryptomator**
   - Kelebihan Cryptomator:
     * Integrasi cloud storage
     * Client-side encryption
     * Open source
   - Kelebihan LockVerse:
     * Lebih sederhana digunakan
     * Tidak bergantung cloud
     * Progress log untuk demo
     * Fitur restore/undo yang lebih baik

## Kesimpulan
LockVerse mengimplementasikan prinsip-prinsip OOP dalam bentuk aplikasi enkripsi file yang praktis dan aman. Meskipun masih ada ruang pengembangan (seperti migrasi ke AES-GCM dan penambahan fitur kompresi), aplikasi ini sudah menyediakan solusi enkripsi yang lebih user-friendly dibanding alternatif yang ada, dengan tetap mempertahankan standar keamanan yang tinggi.