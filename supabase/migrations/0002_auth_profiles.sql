-- Run AFTER 0001_foundation.sql, once, in Supabase SQL Editor.
-- Safe to re-run: constraints/indexes/policies are named and guarded.
create extension if not exists pgcrypto;
alter table public.profiles
 add column if not exists bio text,
 add column if not exists phone text,
 add column if not exists province text,
 add column if not exists city text,
 add column if not exists skills text[] not null default '{}',
 add column if not exists interests text[] not null default '{}',
 add column if not exists languages text[] not null default '{}',
 add column if not exists avatar_path text,
 add column if not exists banner_path text,
 add column if not exists availability text not null default 'available',
 add column if not exists birth_date date,
 add column if not exists gender text,
 add column if not exists education text,
 add column if not exists experience text,
 add column if not exists alternative_email text,
 add column if not exists whatsapp text,
 add column if not exists street_address text,
 add column if not exists postal_code text;
-- Normalize username and phone before enforcing uniqueness.
create unique index if not exists profiles_username_lower_unique on public.profiles (lower(username)) where username is not null;
create unique index if not exists profiles_phone_unique on public.profiles(phone) where phone is not null;
do $$ begin
 if not exists(select 1 from pg_constraint where conname='profiles_username_format') then
  alter table public.profiles add constraint profiles_username_format check (username is null or username ~ '^[a-z0-9_]{3,24}$');
 end if;
 if not exists(select 1 from pg_constraint where conname='profiles_bio_length') then
  alter table public.profiles add constraint profiles_bio_length check (bio is null or char_length(bio)<=500);
 end if;
 if not exists(select 1 from pg_constraint where conname='profiles_phone_format') then
  alter table public.profiles add constraint profiles_phone_format check (phone is null or phone ~ '^08[0-9]{8,11}$');
 end if;
 if not exists(select 1 from pg_constraint where conname='profiles_experience_length') then
  alter table public.profiles add constraint profiles_experience_length check (experience is null or char_length(experience)<=300);
 end if;
 if not exists(select 1 from pg_constraint where conname='profiles_availability_valid') then
  alter table public.profiles add constraint profiles_availability_valid check (availability in ('available','busy'));
 end if;
end $$;
create or replace function public.profile_updated_at() returns trigger language plpgsql set search_path='' as $$ begin new.updated_at=now();return new;end $$;
drop trigger if exists set_profile_updated_at on public.profiles;
create trigger set_profile_updated_at before update on public.profiles for each row execute function public.profile_updated_at();
-- Column grants: user cannot change identity, timestamp, or protected fields via UPDATE.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (display_name,username,bio,phone,province,city,skills,interests,languages,avatar_path,banner_path,availability,birth_date,gender,education,experience,alternative_email,whatsapp,street_address,postal_code) on public.profiles to authenticated;
alter table public.profiles enable row level security;
alter table public.roles enable row level security;
-- Keep original policies from migration 0001; avoid permissive global public reads.
-- Username availability is intentionally checked by SECURITY DEFINER with restricted output.
create or replace function public.username_available(candidate text)
returns boolean language sql stable security definer set search_path='' as $$
 select candidate ~ '^[a-z0-9_]{3,24}$' and not exists(
  select 1 from public.profiles where lower(username)=lower(candidate) and id <> (select auth.uid())
 );
$$;
revoke all on function public.username_available(text) from public, anon;
grant execute on function public.username_available(text) to authenticated;
-- Existing Auth users that predate trigger creation.
insert into public.profiles(id)
select id from auth.users on conflict(id) do nothing;
-- Private bucket: access to objects only under own auth UID prefix.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-media','profile-media',false,2097152,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=2097152,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists "profile media select own" on storage.objects;
drop policy if exists "profile media insert own" on storage.objects;
drop policy if exists "profile media update own" on storage.objects;
drop policy if exists "profile media delete own" on storage.objects;
create policy "profile media select own" on storage.objects for select to authenticated using(bucket_id='profile-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "profile media insert own" on storage.objects for insert to authenticated with check(bucket_id='profile-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "profile media update own" on storage.objects for update to authenticated using(bucket_id='profile-media' and (storage.foldername(name))[1]=(select auth.uid())::text) with check(bucket_id='profile-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy "profile media delete own" on storage.objects for delete to authenticated using(bucket_id='profile-media' and (storage.foldername(name))[1]=(select auth.uid())::text);
