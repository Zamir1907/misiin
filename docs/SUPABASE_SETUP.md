# Supabase setup — tahap 1

1. Buka https://supabase.com/dashboard dan buat proyek.
2. Pilih SQL Editor > New query.
3. Buka `supabase/migrations/0001_foundation.sql` di VS Code, salin seluruh isinya dan tempel di SQL Editor. Klik Run. Jangan drag file ke Table Editor.
4. Buka Table Editor dan pastikan `profiles` dan `roles` terlihat. Tabel lain dibuat pada tahap selanjutnya.
5. Buka Project Settings > API Keys (lokasi menu dapat berubah). Salin Project URL dan publishable key / anon key.
6. Buka `assets/js/config/supabase.js`, ganti dua nilai `PASTE_...` dengan URL dan key publik tadi, simpan.
7. Buka Authentication > Providers > Email, pastikan Email aktif. Atur URL konfigurasi dan redirect URLs sesuai localhost dan domain produksi.
8. Daftar di /register.html; jika konfirmasi email diaktifkan, verifikasi melalui email. Kemudian login di /login.html.

PENTING: jangan pernah menyalin service_role key ke file JS frontend.
