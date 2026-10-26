# MISIIN — Source Code Tahap 1–14

**STATUS: NOT PRODUCTION READY.** Paket final Tahap 14 adalah hasil konsolidasi source code dan dokumentasi, bukan bukti pengujian Supabase/Cloudflare live.

## Mulai dari sini

1. **Pemula:** [`docs/STAGE_14_START_HERE.md`](docs/STAGE_14_START_HERE.md)
2. **Migration SQL & RLS:** [`docs/STAGE_14_DATABASE_CHECKLIST.md`](docs/STAGE_14_DATABASE_CHECKLIST.md)
3. **GitHub & Cloudflare Pages:** [`docs/STAGE_14_DEPLOYMENT.md`](docs/STAGE_14_DEPLOYMENT.md)
4. **Pengujian:** [`docs/STAGE_14_QA_CHECKLIST.md`](docs/STAGE_14_QA_CHECKLIST.md)
5. **Status fitur & blokir produksi:** [`docs/STAGE_14_FEATURE_STATUS.md`](docs/STAGE_14_FEATURE_STATUS.md)
6. **Masalah umum:** [`docs/STAGE_14_TROUBLESHOOTING.md`](docs/STAGE_14_TROUBLESHOOTING.md)

## Cepat: localhost

```bash
py -m http.server 5500
```
Buka `http://localhost:5500/`. **Wajib** konfigurasi `assets/js/config/supabase.js` dan jalankan migration `0001`–`0009` berurutan untuk fitur backend. Python HTTP server **tidak** menjalankan Cloudflare Functions.

## Tes offline

```bash
py scripts/responsive_audit.py
py scripts/functional_security_audit.py
node --test tests/payment-webhook.test.mjs
```

Dokumentasi tiap tahap lama tetap tersedia di `docs/`. Seed misi masih draft; gateway pembayaran belum terintegrasi dan webhook menolak aktivasi yang tidak terverifikasi.

## Revisi UI dan diagnostik
Baca `docs/REVISION_UI_SETUP.md` untuk perbaikan tampilan, QRIS, role admin, misi, dompet, dan bantuan.


## Revisi katalog & settlement internal
Baca `docs/FINAL_CHANGES.md` untuk migrasi 0010, seed 108 misi, dan penjadwalan settlement.
