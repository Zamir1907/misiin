# Integrasi gateway QRIS

**Belum terhubung ke payment gateway nyata.**

Gunakan merchant account resmi, buat QRIS dinamis untuk tiap `order_code`, simpan gateway transaction ID di backend, dan tampilkan QRIS hasil provider. Jangan gunakan URL QRIS statis sebagai bukti pembayaran.

Untuk Midtrans/Xendit/DOKU, buat adapter backend yang memvalidasi signature resmi gateway, status settled/paid, ID merchant, nominal, currency, order, dan ID transaksi. Hanya adapter tepercaya yang boleh mengirim event internal ber-HMAC ke `/api/payment/webhook`. Secret hanya disimpan di Cloudflare.

Tidak boleh memanggil `plus_verify_payment` dari frontend atau membuat webhook publik yang menerima status paid tanpa autentikasi kuat.
