# Revisi logout, pergantian akun, tema admin, dan status misi

## Penyebab yang ditemukan
- `auth-page.js` secara otomatis mengalihkan akun yang masih memiliki sesi Supabase ke dashboard. Sekarang halaman login dan daftar tetap terbuka agar pengguna bisa memilih akun lain.
- Listener logout dashboard dipasang **setelah** beberapa operasi `await` memuat halaman; jika modul atau query gagal, tombol keluar tidak punya handler. Listener sekarang dipasang sejak modul dijalankan.
- Logout memakai `auth.signOut({scope:'local'})` dengan error handling, status tombol, dan redirect `login.html?logged_out=1` hanya setelah berhasil.
- CSS admin sebelumnya memakai warna hard-coded dan sebagian aturan dark mode saling menimpa. `admin-refine.css` kini menggunakan variabel tema dan dimuat paling akhir.

## Cara memperbarui
1. Cadangkan website lama. Ekstrak ZIP baru, ganti source website, dan **pertahankan URL serta publishable/anon key Supabase** dari konfigurasi lama.
2. Tidak ada migration baru. **Jangan** menghapus atau mengulang SQL migration `0001`–`0009`.
3. Refresh browser dengan Ctrl+Shift+R untuk menghindari cache CSS/JS lama.
4. Tes akun A: masuk → keluar → halaman login tetap tampil kosong → masuk akun B.
5. Tes akun admin: login → `/admin.html` → keluar → login lagi sebagai akun biasa.
6. Coba dark/light mode pada `/admin.html`, tabel, formulir, dan sidebar.

## Tentang browser autofill
Form dibersihkan pada load/pageshow dan diberi `autocomplete=off`. **Browser dan password manager tertentu dapat tetap mengisi field**. Jika demikian, nonaktifkan autofill/password manager untuk domain Misiin atau hapus kredensial tersimpan di browser. Pengguna tetap harus menekan tombol Masuk; aplikasi tidak mengirim formulir secara otomatis.

## Tentang misi
`supabase/seed_missions.sql` menyediakan 108 brief contoh dengan status `draft`, kebanyakan `plus_only=true`, dan deadline relatif terhadap saat seed dijalankan. **Tidak otomatis tampil di katalog**. Setelah memastikan tugas, imbalan, pendanaan, dan tanggalnya valid, admin harus menerbitkan misi dari dashboard. Jangan memublikasikan tugas contoh sebagai pekerjaan berbayar sungguhan tanpa penanggung jawab dan anggaran yang nyata.

## Batas pengujian
Pemeriksaan sintaks JavaScript, aset HTML, dan ZIP dilakukan secara offline. Logout, login dengan akun nyata, dan rendering browser belum diuji pada Supabase live.
