-- Misiin Plus visual preview: available to ALL signed-in accounts.
-- This deliberately does NOT grant a paid membership or wallet bonus.
-- Run once in Supabase SQL Editor. No per-user whitelist is required.
create table if not exists public.misiin_plus_previews (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '60 minutes'),
  preview_activated_at timestamptz
);
alter table public.misiin_plus_previews enable row level security;
revoke all on public.misiin_plus_previews from public, anon, authenticated;

create or replace function public.misiin_preview_plus_state()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := (select auth.uid()); p public.misiin_plus_previews;
begin
 if u is null then raise exception 'Silakan login terlebih dahulu'; end if;
 select * into p from public.misiin_plus_previews where user_id=u;
 if not found then return null; end if;
 return jsonb_build_object('id',p.user_id,'created_at',p.created_at,'expires_at',p.expires_at,'preview_activated_at',p.preview_activated_at);
end $$;

create or replace function public.misiin_preview_plus_order()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare u uuid := (select auth.uid()); p public.misiin_plus_previews;
begin
 if u is null then raise exception 'Silakan login terlebih dahulu'; end if;
 insert into public.misiin_plus_previews(user_id) values(u) on conflict (user_id) do nothing;
 select * into p from public.misiin_plus_previews where user_id=u for update;
 if p.preview_activated_at is null and p.expires_at <= now() then
  update public.misiin_plus_previews set created_at=now(),expires_at=now()+interval '60 minutes'
  where user_id=u returning * into p;
 end if;
 return jsonb_build_object('id',p.user_id,'created_at',p.created_at,'expires_at',p.expires_at,'preview_activated_at',p.preview_activated_at);
end $$;

create or replace function public.misiin_preview_plus_activate()
returns boolean language plpgsql security definer set search_path = '' as $$
declare u uuid := (select auth.uid()); p public.misiin_plus_previews;
begin
 if u is null then raise exception 'Silakan login terlebih dahulu'; end if;
 select * into p from public.misiin_plus_previews where user_id=u for update;
 if not found then raise exception 'Mulai sesi QRIS terlebih dahulu'; end if;
 if p.preview_activated_at is not null then return true; end if;
 if p.expires_at <= now() then raise exception 'Waktu sesi habis. Perbarui sesi pembayaran'; end if;
 if now() < p.created_at + interval '20 seconds' then raise exception 'Tunggu 20 detik sebelum konfirmasi'; end if;
 update public.misiin_plus_previews set preview_activated_at=now() where user_id=u;
 return true;
end $$;
revoke all on function public.misiin_preview_plus_state(),public.misiin_preview_plus_order(),public.misiin_preview_plus_activate() from public,anon;
grant execute on function public.misiin_preview_plus_state(),public.misiin_preview_plus_order(),public.misiin_preview_plus_activate() to authenticated;
