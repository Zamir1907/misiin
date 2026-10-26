# Patch Misiin Plus — pratinjau untuk semua akun

Patch ini mengganti aktivasi yang memerlukan whitelist UUID dengan **pratinjau visual** yang dapat dicoba oleh semua pengguna yang login. Status pratinjau disimpan di Supabase dan tetap ada setelah refresh/login ulang. **Ini bukan aktivasi keanggotaan berbayar**: tabel `memberships`, saldo, bonus Rp4.500, dan akses misi berbayar tidak diubah. Gambar QRIS tetap menggunakan URL yang dikonfigurasi.

## Pasang

1. Salin `assets/js/plus-page.js` dari patch ke path yang sama dalam proyek lama.
2. Buka Supabase Dashboard → SQL Editor, lalu jalankan `supabase/migrations/0012_plus_preview_semua_akun.sql` **satu kali**. Tidak perlu memasukkan UUID siapa pun.
3. Jalankan `python -m http.server 8000` dari folder proyek lama, lalu buka `http://localhost:8000` dan login.
4. Pilih metode pembayaran → QRIS → tunggu 20 detik → klik **Saya Sudah Membayar**. Status pratinjau tersimpan dalam `public.misiin_plus_previews`.

## Catatan

- File SQL `0011_test_plus_persistent_checkout.sql` dari patch sebelumnya tidak perlu dijalankan untuk fitur pratinjau ini.
- Bila sudah terpasang, RPC lama tetap ada namun tidak digunakan oleh `plus-page.js` versi ini. Sebelum publikasi, pertimbangkan mencabut akses eksekusi RPC pengujian lama (`misiin_test_plus_activate`, dll.) jika tidak dibutuhkan.
- CSS QRIS, scrollbar, notifikasi, dan Pusat Bantuan dari patch sebelumnya tetap dipakai; patch ini tidak mengubahnya.
- Pengguna yang benar-benar sudah Plus tetap akan terlihat sebagai anggota Plus.
