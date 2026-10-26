# Misiin — Panduan Responsive Tahap 12

## Instalasi
Tidak ada migration SQL baru. Ekstrak ZIP terbaru, gunakan konfigurasi Supabase sebelumnya, lalu jalankan `py -m http.server 5500` dari folder `misiin`. CSS `responsive-fixes.css` otomatis dimuat terakhir pada semua halaman HTML.

## Ukuran yang harus diuji
320, 375, 390, 414, 430, 768, 1024, 1280, 1366, dan 1440 piksel; khusus laptop 1366 × 768.

## Prosedur pengujian manual
1. Buka Chrome DevTools (F12) → Toggle Device Toolbar (Ctrl+Shift+M).
2. Masukkan ukuran satu per satu, muat ulang, periksa scroll horizontal pada `document.documentElement.scrollWidth > window.innerWidth`.
3. Uji halaman publik, login, register, reset password, dashboard, misi, dompet, Plus, tiket, profil, pengaturan, dan admin.
4. Pada <768px: bottom navigation pengguna; drawer menu admin; tabel admin tampil sebagai kartu.
5. Pada 768–1024px: menu pengguna dan admin harus berupa drawer. Pada >1024px: sidebar tetap.
6. Coba membuka/menutup drawer dengan tombol, backdrop, dan Escape. Uji Tab, Shift+Tab, fokus, zoom 200%, orientasi landscape.
7. Periksa form 320px, pesan validasi panjang, URL panjang, bukti upload, teks rupiah panjang, tabel kosong.
8. Uji Chrome, Firefox, Edge dan Safari iOS pada perangkat/browser nyata jika tersedia.
9. Uji `prefers-reduced-motion` dan throttling CPU 4×; pantau LCP, CLS, dan respons input di DevTools Performance.

## Batas pengujian
Audit otomatis hanya mengecek struktur file, sintaks JavaScript, pemuatan stylesheet dan aturan media query. Itu tidak membuktikan layout bebas overflow pada browser nyata. Pengujian visual dan interaksi browser harus dilakukan manual.
