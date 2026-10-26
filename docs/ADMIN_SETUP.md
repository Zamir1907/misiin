# Membuat super admin pertama
1. Buat akun melalui `register.html`, lalu verifikasi email.
2. Supabase Dashboard > Authentication > Users > cari email admin > salin **User UID** (UUID).
3. Supabase Dashboard > SQL Editor > New query. Jalankan SQL berikut dengan mengganti UUID:

```sql
insert into public.roles(user_id,role)
values ('GANTI_DENGAN_UUID_ADMIN','super_admin')
on conflict(user_id,role) do nothing;
```

4. Logout lalu login kembali di `login.html`. Sistem mengarahkan ke `/admin.html`.
5. User biasa tidak boleh bisa menulis `roles` lewat frontend (uji via API/RLS).
6. Jangan pernah menaruh service_role key di JavaScript browser atau repository.

Catatan: dashboard admin saat ini hanya kerangka akses; fitur manajemen misi dan transaksi menyusul.
