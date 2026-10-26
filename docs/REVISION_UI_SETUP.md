# Misiin — Revisi UI dan diagnostik (setelah Tahap 14)

## Apa yang diperbaiki di source
- Logo **lettermark m** dibuat dari teks/CSS, bukan gambar hasil generasi. Semua header dan footer memakai mark baru; favicon lama tidak digunakan.
- Login/register ditengahkan konsisten dengan flex layout; loading startup dashboard ditengahkan.
- Sidebar pengguna/admin dapat discroll saat menu panjang.
- Tema gelap memakai token CSS global untuk permukaan, teks, border, input, tombol sekunder. Preferensi tema disimpan di localStorage browser saat disimpan di Pengaturan dan dipakai halaman lain. Tema akun lintas perangkat tetap memerlukan sinkronisasi pada halaman yang dibuka.
- Halaman Plus: manfaat, ringkasan harga, tahap checkout, informasi verifikasi, tombol kembali, dan pesan kesalahan pembayaran yang menjelaskan HTTP/HTML.
- Beranda: statistik saldo, misi berjalan, misi disetujui, dan status Plus dibaca dari Supabase. Kegagalan query ditampilkan, bukan angka palsu.

## Mengapa muncul Unexpected token '<' ketika bayar QRIS?
Kode lama memanggil `response.json()` tanpa memeriksa isi respons. Jika `/api/payment/create` mengembalikan HTML (`<!DOCTYPE html>`), JSON parser gagal. Penyebab umum: menjalankan website lewat `python -m http.server`/Live Server yang **tidak menjalankan Cloudflare Pages Functions**, atau deploy Cloudflare salah root sehingga fallback HTML. Kode baru menampilkan pesan diagnostik; **tidak mengaktifkan gateway pembayaran**.

Cek di browser DevTools > Network > `/api/payment/create`: status HTTP, Response, dan content-type. Jika HTML, jangan anggap itu jawaban dari backend pembayaran. Jalankan dengan Cloudflare Pages Functions menggunakan Wrangler/Pages dev sesuai konfigurasi proyek, atau deploy ke Cloudflare Pages dengan root folder `misiin` dan folder `functions/` pada root deploy. Set environment variable di Cloudflare: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (hanya server, jangan commit). Gunakan environment staging dan jangan melakukan pembayaran nyata: webhook gateway saat ini sengaja dinonaktifkan.

## Mengapa roles kosong untuk pengguna biasa?
`public.roles` di proyek ini adalah **daftar khusus super_admin**, bukan daftar seluruh pengguna. Pengguna biasa hanya ada di `auth.users` dan `public.profiles`. Ini perilaku desain, bukan bug. Untuk mempromosikan **akun sendiri yang sudah terdaftar**, gunakan SQL Editor dengan hak pemilik proyek dan UUID akun dari Authentication > Users:

```sql
-- Ganti UUID dengan ID akun milikmu yang benar (jangan pakai email).
insert into public.roles (user_id, role)
values ('00000000-0000-0000-0000-000000000000'::uuid, 'super_admin')
on conflict (user_id, role) do nothing;
```

Pastikan UUID diganti sebelum Run. Jangan memberi akses SQL Editor atau service_role kepada pengguna. Logout lalu login ulang dan buka `/admin.html`. Untuk cek:

```sql
select p.id,p.display_name,r.role
from public.profiles p left join public.roles r on r.user_id=p.id
order by p.created_at desc limit 30;
```

## Mengapa misi tidak muncul?
Migration `0003` membuat skema misi, tetapi **tidak otomatis mempublikasikan semua misi**. Misi dengan `status='draft'`, deadline lewat, atau tidak ada data tidak muncul di katalog (`status='published'`). Periksa di SQL Editor:

```sql
select status,count(*) from public.missions group by status;
select id,title,status,deadline,quota,plus_only
from public.missions order by created_at desc limit 20;
```

Buat/publikasikan hanya misi yang nyata, sah, siap direview, dan benar-benar akan diberi imbalan melalui dashboard admin. Jangan mempublikasikan misi contoh sebagai penawaran berbayar nyata.

## Mengapa Pusat Bantuan kosong?
Tiket baru **tidak dibuat oleh migration**. Halaman tiket semestinya menyediakan form membuat tiket, tetapi daftar tiket pengguna akan kosong sampai ada tiket. Cek SQL:

```sql
select count(*) as total_tickets from public.support_tickets;
select category,status,count(*) from public.support_tickets group by category,status;
```

Jika UI malah gagal dimuat, buka DevTools > Console/Network dan periksa error `permission denied`, `function ... does not exist`, atau `relation ... does not exist`. Pastikan `0006_support.sql` dan migration setelahnya benar-benar sukses tanpa error. Login dengan akun biasa untuk menguji RLS. Storage `support-attachments` harus private; jangan mengubahnya menjadi public untuk mengatasi error.

## Mengapa saldo atau bonus 0?
Lihat saldo dari ledger, bukan dengan mengubah angka di frontend:

```sql
select w.user_id,coalesce(sum(l.amount),0) as balance
from public.wallets w left join public.wallet_ledger l on l.user_id=w.user_id
group by w.user_id order by balance desc limit 30;
select kind,count(*),sum(amount) from public.wallet_ledger group by kind;
```

Jika wallet row belum ada, periksa trigger signup dari migration `0004`. Jangan menyisipkan kredit bonus manual tanpa audit dan idempotency.

## Pengujian yang masih wajib
1. Chrome/Edge: 320, 375, 768, 1024, 1366, 1440px, termasuk scroll sidebar dan tampilan modal.
2. Tema terang/gelap di login, register, Beranda, misi, dompet, Plus, bantuan, pengaturan, admin. Periksa kontras semua input dan tombol.
3. Dua akun biasa dan satu admin: tiket hanya terlihat pemilik/admin, role tidak bisa ditulis pengguna, saldo dan misi tidak bocor antar-akun.
4. Uji API Cloudflare Functions pada staging: 401 tanpa token, JSON error untuk kesalahan backend, dan webhook tetap menolak pembayaran tidak terverifikasi.
5. Uji transaksi wallet, review, withdrawal secara nyata pada Supabase staging sebelum produksi.

**Batasan:** Perbaikan ini diuji secara statis (syntax/aset). Tidak ada pengujian browser interaktif, Supabase live, gateway QRIS, atau Cloudflare live dalam paket ini.
