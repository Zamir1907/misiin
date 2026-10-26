# Misiin Patch 0018 — file berubah saja

## Pemasangan
1. Backup repository saat ini.
2. Salin `app.html` dan direktori `assets/` dari ZIP ini ke root repository GitHub yang terhubung Cloudflare Pages. Timpa file yang sama, jangan hapus file lain.
3. Commit/push dan periksa deployment Cloudflare Pages sukses.
4. Pastikan URL `/assets/css/patch-0018.css?v=0018` terbuka, lalu hard refresh.
5. Uji dengan akun Free dan akun Plus pada halaman Beranda, Cari Misi, Plus, Pengaturan, Pusat Bantuan, Notifikasi.

## SQL
**Tidak ada migration SQL baru pada patch 0018.** Tabel `notifications`, `support_tickets`, `support_messages`, `memberships`, dan trigger sudah terlihat ada di screenshot. Jangan jalankan ulang semua migration atau membuat trigger duplikat. Jika tiket tetap gagal, catat pesan error di halaman dan periksa RLS/RPC serta isi database; jangan menjalankan SQL tambahan tanpa diagnosa.

## Perubahan
- Satu kali pembacaan membership di dashboard; menghapus permintaan tambahan yang menyebabkan label Free/Plus saling menimpa.
- Pusat Bantuan menampilkan formulir yang dapat dibuka, menampilkan pesan error RPC, dan daftar tiket jika ada.
- Notifikasi memiliki tombol Perbarui/Coba lagi.
- Pengaturan diringkas menjadi empat tab yang berguna.
- Modal metode pembayaran disederhanakan menjadi checkout QRIS saja, desain baru.
- Kartu reward diperbesar dan diberi hierarki visual yang jelas.
- Label deadline katalog dibedakan dari batas penyelesaian pekerjaan. **Perhitungan deadline per-claim belum diubah pada backend.**

## Batasan penting
Belum diuji langsung dengan database Supabase produksi, sehingga tidak bisa menjamin semua fitur backend bekerja. Aktivasi menggunakan fungsi `misiin_plus_activate_internal` dari database yang sudah ada. Sistem yang langsung mengaktifkan Plus setelah konfirmasi pengguna tidak otomatis menjadi bukti pembayaran QRIS telah diterima. Pengumuman terjadwal masih membutuhkan scheduler jika ingin otomatis muncul tepat waktu. Pengaturan dan fitur Plus tertentu yang lebih kompleks tetap memerlukan peninjauan end-to-end tersendiri.
