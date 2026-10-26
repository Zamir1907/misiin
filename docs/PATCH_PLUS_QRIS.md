# PATCH Misiin Plus — 26 Oktober 2026

Patch hanya berisi file yang berubah, dengan struktur folder yang sama seperti website asli. Ekstrak lalu **salin isi folder `misiin/`** ke folder proyek Misiin lama, dan izinkan timpa file. Cadangkan proyek sebelumnya terlebih dahulu.

## Diubah
- `assets/js/plus-page.js`: popup pilihan metode (QRIS aktif; transfer bank, e-wallet, kartu tidak tersedia), skeleton loading gambar QRIS, timer 60 menit, tombol konfirmasi menunggu 20 detik, transisi sukses, halaman anggota aktif.
- `assets/css/plus.css`: desain popup, kartu QRIS berbayang, animasi loading dan sukses.
- `functions/api/payment/internal-activate.js`: mengizinkan pengujian pada domain Cloudflare *jika* mode pengujian diaktifkan dan akun ada dalam daftar izin.
- `assets/js/dashboard.js`: mengganti kalimat teknis dan placeholder.
- `assets/js/mission-page.js`: mengganti kalimat teknis Supabase.
- `assets/js/support-page.js`: memperbaiki empty state notifikasi dan deskripsi bantuan.
- `assets/js/settings-page.js`: memperbaiki teks preferensi notifikasi.

## Ditambahkan
- `docs/PATCH_PLUS_QRIS.md`: petunjuk ini.

## Pengujian aktivasi
Endpoint membutuhkan Cloudflare Pages Functions (tidak bekerja dengan `python -m http.server`). Pada lingkungan pengujian set `MISIIN_INTERNAL_TEST_MODE=enabled`, `MISIIN_TEST_USER_ID=<UUID akun penguji>`, `SUPABASE_URL`, dan `SUPABASE_SERVICE_ROLE_KEY` sebagai secret server. Pada localhost Wrangler, gunakan `.dev.vars`; pada deployment pengujian, gunakan environment variables/secret Cloudflare. Jangan simpan service role key dalam JS browser atau GitHub. **Jangan aktifkan mode pengujian pada website produksi.**

Gambar QRIS default: https://cdn.aceimg.com/TNrRn6dtw.jpg (bisa diganti dari app_settings.qris_image_url). Gambar QRIS bukan verifikasi pembayaran; aktivasi instan hanya untuk akun pengujian yang diizinkan.

## Batas pengujian
Sintaks JavaScript diperiksa, tetapi integrasi Supabase, RLS, dan Cloudflare tidak dapat diuji tanpa kredensial proyek. Fitur Pusat Bantuan dan Notifikasi menggunakan tabel Supabase yang sudah dirujuk oleh kode; pastikan migrasi dan kebijakan RLS sudah diterapkan.
