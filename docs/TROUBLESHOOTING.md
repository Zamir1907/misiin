# Troubleshooting

- Halaman putih: cek DevTools > Console, jalankan melalui localhost bukan file://.
- Login gagal dengan `Supabase belum dikonfigurasi`: isi `assets/js/config/supabase.js` dengan Project URL dan public key yang benar.
- `relation roles does not exist`: jalankan migration 0001 lewat SQL Editor.
- Email belum diverifikasi: buka email verifikasi atau periksa pengaturan Authentication.
- CORS / Auth redirect: periksa Site URL dan Redirect URLs di Supabase.
- `/api/health` 404 pada Python local server: gunakan Cloudflare Pages dev atau deploy Pages; Python server hanya melayani static files.
