-- Mengaktifkan akses Plus langsung ketika tombol konfirmasi ditekan.
-- Keanggotaan bukan bukti uang QRIS sudah diterima.
-- Terapkan hanya pada proyek yang memang mengizinkan aktivasi tanpa verifikasi.
insert into public.misiin_internal_flags(key,enabled) values ('instant_plus',true)
on conflict(key) do update set enabled=excluded.enabled;
