# Misiin patch 0015 — hanya file yang berubah

1. Cadangkan proyek dan database.
2. Salin isi ZIP ke root proyek, pertahankan struktur folder.
3. Jalankan `supabase/migrations/0015_notifications_and_support.sql` melalui Supabase SQL Editor **setelah** 0006 dan 0007.
4. Deploy ulang dan hard refresh browser.
5. Uji akun Free dan Plus, kirim tiket, balas dari admin, terbitkan pengumuman, lalu periksa notifikasi.

## Catatan
- Pengumuman berstatus published dengan jadwal masa depan belum otomatis terbit pada waktunya; butuh scheduler tambahan. Pengumuman yang dipublikasikan sekarang menghasilkan notifikasi untuk akun yang sudah ada.
- Patch ini memperbaiki bug form akses field dan status beranda, tetapi belum diverifikasi terhadap Supabase aktif.
- Jangan jalankan migration lama berulang kali tanpa memahami perubahan datanya.
- Tidak mengubah logika aktivasi Plus dari 0014.
