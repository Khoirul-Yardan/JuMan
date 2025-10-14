# LockVerse Flutter — README (Ringkas)

LockVerse adalah aplikasi Flutter desktop/mobile yang menyimpan file secara terenkripsi di sebuah "vault" lokal. Tujuan utamanya adalah menyimpan dokumen pribadi dengan enkripsi yang kuat, manajemen kunci, dan pengalaman pengguna yang aman.

## Fitur utama
- Enkripsi per-file menggunakan AES-CBC.
- Per-file symmetric key (32 byte) yang dienkripsi (wrapped) menggunakan root key.
- Root key dilindungi (wrapped) oleh master key yang diturunkan dari password pengguna (PBKDF2) dan backup recovery code.
- File terenkripsi disimpan di direktori aplikasi (vault). File asli dihapus setelah berhasil dienkripsi (opsi ini bisa diubah ke 'pindah' jika diinginkan).
- Saat membuka file terenkripsi, file didekripsi ke file sementara (preserve extension) dan dibuka menggunakan aplikasi default OS.

## Struktur proyek (singkat)
- `lib/services/encryption_service.dart` — utilitas enkripsi: PBKDF2, random bytes, encrypt/decrypt helper wrappers yang menggunakan paket `encrypt`.
- `lib/services/key_manager.dart` — manajemen master/root key: inisialisasi, penyimpanan, wrapping/unwrapping root key.
- `lib/services/file_manager_service.dart` — logika penyimpanan file terenkripsi, membuka file (decrypt ke temp file + open), dan penjadwalan penghapusan temp file.
- `lib/screens/add_files_screen.dart` — UI untuk memilih berkas, enkripsi, dan menyimpan metadata ke database.
- `lib/services/document_service.dart` — (lokal) penyimpanan metadata dokumen.

## Cara pakai (pengguna)
1. Jalankan aplikasi Flutter (desktop atau mobile).
2. Buat akun / set master password (inisialisasi KeyManager).
3. Gunakan "Add Files" untuk memilih file.
4. Aplikasi akan mengenkripsi file, menyimpan blob terenkripsi di vault, menyimpan metadata, lalu menghapus file asli.
5. Buka file dari daftar dokumen — aplikasi akan mendekripsi ke file sementara dan membuka aplikasi default OS.

## Konsep Pemrograman Berorientasi Objek (PBO) yang Diimplementasikan
Dokumen ini menjelaskan konsep OOP yang digunakan di proyek ini dan bagaimana mereka diimplementasikan:

1. Kelas dan Encapsulation
	- Contoh: `EncryptionService`, `KeyManager`, `FileManagerService`, `DocumentService`, `AuthService`.
	- Masing-masing kelas membungkus tanggung jawab tertentu: enkripsi, manajemen kunci, manajemen file, penyimpanan metadata, autentikasi.
	- Properti yang sensitif (seperti kunci dalam `KeyManager`) hanya diakses melalui method publik yang aman.

2. Abstraction
	- Fungsionalitas kriptografi diisolasi dalam `EncryptionService`. Pengguna kelas lain tidak perlu mengetahui detail implementasi (mode AES, padding, atau PBKDF2).
	- `DocumentService` menyembunyikan detail penyimpanan SQLite dari UI.

3. Single Responsibility Principle (SRP)
	- Setiap kelas mempunyai tanggung jawab tunggal: `KeyManager` (kunci), `FileManagerService` (file), `EncryptionService` (operasi kripto), `DocumentService` (metadata).

4. Dependency Injection (sederhana)
	- `FileManagerService` menerima `BuildContext` pada konstruktor agar dapat mengakses `Provider` untuk `DocumentService`.
	- `Provider` package digunakan untuk melakukan injeksi sederhana dan reaktif pada UI.

5. Modularity dan Reusability
	- Methods di `EncryptionService` bersifat statis sehingga mudah dipanggil dari berbagai titik tanpa instance.
	- Layanan lain mengonsumsi fungsi ini, memudahkan pengujian unit untuk operasi kripto secara terpisah.

6. Error Handling dan Robustness (prinsip desain OOP)
	- Penting: kelas berinteraksi lewat kontrak method (return types dan exceptions). Kesalahan deskripsi kunci / file yang korup dilempar sebagai `Exception` untuk diproses di lapisan UI.

## Catatan penting & perbaikan yang disarankan
- Saat ini algoritma: AES CBC + PKCS7. CBC memerlukan IV yang unik per-enkripsi (sudah ditangani). Pastikan root/key handling aman dan salt/iteration PBKDF2 memadai (saat ini 10.000 iterasi — pertimbangkan menaikkan sesuai kebutuhan). 
- Untuk keamanan yang lebih baik pertimbangkan AES-GCM (authenticated encryption) untuk mendeteksi manipulasi ciphertext tanpa ambigu PKCS7 padding.
- Perbaiki validasi dan penanganan error agar tidak menampilkan detail teknis ke UI (tampilkan pesan user-friendly).
- Perbaiki analisis statis (fix tipe dynamic di `key_manager.dart` dan `document.dart` yang muncul saat `flutter analyze`).

## Perintah berguna
Jalankan analisis dan build:

```powershell
flutter analyze
flutter pub get
flutter run -d windows
flutter build windows
```

## Lanjutan yang bisa saya bantu
- Implementasi delete-temp-file-on-external-app-exit (desktop) agar file sementara dihapus segera setelah program eksternal ditutup.
- Migrasi ke AES-GCM untuk integritas + kerahasiaan.
- Perbaikan `flutter analyze` warnings/errors (saya bisa mulai memperbaiki `document.dart` dan `key_manager.dart`).

Jika Anda ingin saya tambahkan salah satu perbaikan tersebut sekarang, beri tahu mana yang prioritas (mis. perbaiki `flutter analyze` errors, atau implementasi penghapusan temp file saat app keluar).
