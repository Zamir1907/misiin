# Perubahan versi pengujian Plus
- `assets/js/plus-page.js`: tombol QRIS menggunakan endpoint aktivasi internal lokal, efek transisi dan halaman anggota aktif.
- `assets/css/plus.css`: animasi transisi ke halaman anggota.
- `functions/api/payment/internal-activate.js` (baru): aktivasi akun penguji terpilih, hanya localhost dan mode internal.
- `.dev.vars.example` (baru): contoh konfigurasi lokal tanpa rahasia.
- `docs/INTERNAL_PLUS_SETUP.md` (baru): panduan instalasi dan pengujian.
- `.gitignore`: melindungi `.dev.vars`.

Endpoint pembayaran produksi lainnya tidak dihapus atau diubah. Sistem ini hanya untuk pengujian lokal, bukan verifikasi QRIS. Pengujian integrasi Supabase langsung belum dilakukan.
