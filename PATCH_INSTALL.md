# Misiin — pemasangan patch integrasi Plus & Bantuan

## Cara memasang
1. Buat cadangan folder Misiin lama.
2. Salin **isi folder `misiin/`** dari ZIP patch ini ke folder Misiin lama, lalu timpa file yang sama.
3. Di Supabase SQL Editor, pastikan migrasi lama sampai `0012_plus_preview_semua_akun.sql` sudah dijalankan. Kemudian jalankan `supabase/migrations/0013_plus_internal_integrated.sql`.
4. **Hanya pada project internal yang kamu kontrol**, jalankan SQL ini untuk mengizinkan aktivasi langsung semua akun login (tanpa UUID satu-satu):

```sql
update public.misiin_internal_flags set enabled=true where key='instant_plus';
```

5. Jalankan `python -m http.server 8000` dari folder Misiin dan buka `http://localhost:8000/app.html`.
6. Uji akun Free → QRIS → tunggu 20 detik → Saya Sudah Membayar → cek `memberships` di Supabase → coba ambil misi Plus → buka Ruang Produktivitas → buat tiket di Bantuan & Pengaduan.

## Penting
- Aktivasi instan ini **bukan verifikasi pembayaran QRIS**. Semua akun login dapat memperoleh status Plus ketika switch diaktifkan. **Jangan hidupkan pada proyek yang menerima pembayaran publik.**
- Matikan kembali dengan:
```sql
update public.misiin_internal_flags set enabled=false where key='instant_plus';
```
- Bonus dompet Rp4.500 **tidak diberikan** oleh fungsi aktivasi internal ini karena tidak ada pembayaran yang diverifikasi. Bonus registrasi Rp5.500 tidak diubah.
- Jika Bantuan & Pengaduan menampilkan error riwayat, tombol Kirim Pengaduan tetap muncul. Pastikan migrasi `0006_support.sql` sudah dijalankan dan Storage `support-attachments` tersedia untuk lampiran.
- Ruang Produktivitas menyediakan portofolio, proposal, catatan, target, kalender teks dan Pomodoro. Statistik khusus dan pengingat otomatis **belum dibuat** oleh patch ini; tidak diklaim sudah berfungsi.
- Tidak perlu Wrangler atau `.dev.vars` untuk alur Supabase RPC ini.
- ZIP ini **tidak** memuat `.dev.vars`, service role key, maupun `.wrangler`.
