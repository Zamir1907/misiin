# Instalasi tahap 1

1. Ekstrak ZIP dan buka folder `misiin` dengan VS Code.
2. Klik Terminal > New Terminal.
3. Ketik `python -m http.server 5500` (Windows bisa memakai `py -m http.server 5500`).
4. Buka browser: http://localhost:5500.
5. Landing page harus muncul. Ini belum memerlukan Supabase.
6. Untuk login, ikuti SUPABASE_SETUP.md terlebih dahulu.

Jangan membuka index.html dengan klik ganda (file://) karena modul ES membutuhkan HTTP server.
