# Misiin Plus — pengujian internal lokal

1. Buat akun penguji di Misiin. Ambil UID di Supabase Authentication > Users.
2. Salin `.dev.vars.example` menjadi `.dev.vars` pada folder `misiin`.
3. Isi `MISIIN_TEST_USER_ID` dengan UID akun penguji. Isi URL dan service-role key Supabase di `.dev.vars`. Jangan unggah atau membagikan kunci tersebut.
4. Buka terminal pada folder `misiin` lalu jalankan `npx wrangler pages dev . --port 8788`.
5. Buka `http://localhost:8788`, login sebagai akun penguji, buka Misiin Plus, klik Lanjutkan ke QRIS, tunggu 20 detik, klik Saya Sudah Membayar.
6. Backend lokal akan mengaktifkan keanggotaan untuk UID penguji yang ditentukan. Refresh untuk melihat halaman anggota.

**Penting:** `python -m http.server` tidak menjalankan Functions. Endpoint `internal-activate` hanya menerima hostname localhost/127.0.0.1 dan hanya UID yang diizinkan. Untuk deploy publik, hapus `functions/api/payment/internal-activate.js` dan jangan deploy `.dev.vars`; gunakan verifikasi pembayaran yang sebenarnya. Timer 20 detik tidak membuktikan pembayaran.
