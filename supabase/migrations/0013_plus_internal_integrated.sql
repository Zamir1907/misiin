-- Misiin Plus: aktivasi langsung khusus lingkungan internal yang kamu kendalikan.
-- Tidak ada daftar UUID; semua akun login bisa mengaktifkan saat switch dihidupkan.
-- JANGAN aktifkan switch ini pada website publik dengan transaksi sungguhan.
create table if not exists public.misiin_internal_flags (
 key text primary key, enabled boolean not null default false
);
revoke all on public.misiin_internal_flags from public, anon, authenticated;
insert into public.misiin_internal_flags(key,enabled) values('instant_plus',false)
on conflict(key) do nothing;

create or replace function public.misiin_plus_activate_internal()
returns boolean language plpgsql security definer set search_path = '' as $$
declare u uuid := (select auth.uid()); p public.misiin_plus_previews;
begin
 if u is null then raise exception 'Silakan masuk terlebih dahulu'; end if;
 if not exists (select 1 from public.misiin_internal_flags where key='instant_plus' and enabled) then
   raise exception 'Aktivasi langsung tidak tersedia. Hubungi pengelola Misiin.';
 end if;
 select * into p from public.misiin_plus_previews where user_id=u for update;
 if not found then raise exception 'Mulai sesi QRIS terlebih dahulu'; end if;
 if p.expires_at <= now() then raise exception 'Waktu sesi berakhir. Perbarui pembayaran'; end if;
 if now() < p.created_at + interval '20 seconds' then raise exception 'Silakan tunggu sebelum konfirmasi'; end if;
 insert into public.memberships(user_id,tier,status,activated_at)
 values(u,'plus_lifetime','active',now())
 on conflict(user_id) do update set tier='plus_lifetime',status='active',
 activated_at=coalesce(public.memberships.activated_at,excluded.activated_at);
 update public.misiin_plus_previews set preview_activated_at=coalesce(preview_activated_at,now()) where user_id=u;
 return true;
end $$;
revoke all on function public.misiin_plus_activate_internal() from public,anon;
grant execute on function public.misiin_plus_activate_internal() to authenticated;

-- Workspace pribadi anggota Plus: portofolio, proposal, catatan, target, kalender.
create table if not exists public.misiin_plus_workspace (
 user_id uuid primary key references auth.users(id) on delete cascade,
 content jsonb not null default '{}'::jsonb,
 updated_at timestamptz not null default now()
);
alter table public.misiin_plus_workspace enable row level security;
revoke all on public.misiin_plus_workspace from public,anon,authenticated;
grant select,insert,update on public.misiin_plus_workspace to authenticated;
drop policy if exists plus_workspace_own on public.misiin_plus_workspace;
create policy plus_workspace_own on public.misiin_plus_workspace for all to authenticated
 using(user_id=(select auth.uid()) and public.misiin_has_plus((select auth.uid())))
 with check(user_id=(select auth.uid()) and public.misiin_has_plus((select auth.uid())));

-- AKTIFKAN HANYA DI PROJECT PENGUJIAN YANG TIDAK MEMPROSES UANG NYATA:
-- update public.misiin_internal_flags set enabled=true where key='instant_plus';
-- MATIKAN SEBELUM MEMBUKA TRANSAKSI PUBLIK:
-- update public.misiin_internal_flags set enabled=false where key='instant_plus';
