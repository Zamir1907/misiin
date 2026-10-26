# Revisi Misiin 0014

## Instalasi
1. Cadangkan database dan berkas website sebelumnya.
2. Jalankan migration SQL sebelumnya secara berurutan hingga `0013`, jika belum pernah dijalankan.
3. Jalankan `supabase/migrations/0014_instant_plus_activation.sql` melalui Supabase SQL Editor.
4. Unggah berkas website dari ZIP ini ke Cloudflare Pages, lalu bersihkan cache dan login ulang.
5. Periksa bahwa tabel `memberships` memuat `tier=plus_lifetime` dan `status=active` setelah konfirmasi.

## Penting
- Tombol konfirmasi langsung mengaktifkan keanggotaan; **tidak memverifikasi transfer QRIS**.
- Sistem tidak mengubah `payment_orders.status` menjadi `paid` tanpa bukti.
- Menyalakan mode ini pada situs publik memungkinkan pengguna mengaktifkan Plus tanpa membayar.
- File `.dev.vars` sengaja tidak disertakan. Jika pernah membagikan service role key dalam ZIP, rotasi kuncinya di Supabase dan perbarui secret di Cloudflare.
- Pusat Bantuan sudah memiliki form tiket di `assets/js/support-page.js`; jika hanya teks yang muncul, cek error browser dan RLS migration `0006`.
- Fitur Plus yang lebih kompleks seperti pengingat otomatis dan portofolio publik belum diimplementasikan sepenuhnya dalam revisi ini.
