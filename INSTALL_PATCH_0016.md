# Misiin Patch 0016 — file yang berubah saja

## Instalasi
1. Cadangkan proyek saat ini.
2. Ekstrak ZIP di komputer.
3. Salin `app.html` dan folder `assets` ke **root proyek GitHub** (folder yang juga berisi `index.html`), pertahankan struktur path dan timpa file lama.
4. Commit dan push ke branch yang digunakan Cloudflare Pages. Tunggu status deployment `Success`.
5. Buka `https://DOMAIN-ANDA/assets/css/patch-0016.css?v=0016` dan pastikan CSS terlihat (bukan halaman 404/HTML).
6. Buka `https://DOMAIN-ANDA/app.html?page=support` dan `...page=missions`, lalu hard refresh Ctrl+Shift+R.

## File berubah
- app.html — memuat CSS patch 0016, menghindari status Free sebelum verifikasi
- assets/js/dashboard.js — mengisi status sidebar sejak awal dan menyamakan alur pemuatan
- assets/js/support-page.js — formulir langsung terlihat ketika belum ada tiket; error lebih jelas
- assets/js/mission-page.js — reward lebih menonjol; istilah jenis bukti lebih mudah dipahami
- assets/css/patch-0016.css — desain misi dan formulir bantuan

## SQL
Tidak ada SQL baru untuk patch ini. Pastikan migration 0006_support.sql, 0007_admin.sql, dan 0015_notifications_and_support.sql sudah berhasil dijalankan di database Supabase yang dipakai website. Jangan menjalankan ulang seluruh migrasi tanpa meninjau dependensi.

## Batasan penting
- Pengiriman tiket, pembacaan notifikasi, dan akses Plus memerlukan koneksi Supabase dan RLS/RPC yang benar. Patch belum diuji end-to-end terhadap proyek Supabase pengguna.
- Notifikasi hanya muncul jika ada kejadian yang mencatat notifikasi di database. Pengumuman terjadwal di masa depan masih memerlukan scheduler.
- Deadline misi masih berasal dari kolom `missions.deadline` (tanggal tetap). Patch ini TIDAK mengubahnya menjadi tenggat relatif sejak pengambilan; perubahan itu memerlukan desain migration dan RPC terpisah.
- Jangan mengunggah file `.dev.vars`, secret, atau service-role key ke GitHub.
