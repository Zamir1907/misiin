-- Stage 1: authentication profile and protected role foundation. Run once in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.profiles (id uuid primary key references auth.users(id) on delete cascade,display_name text,username text unique,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table if not exists public.roles (user_id uuid not null references auth.users(id) on delete cascade,role text not null check(role in ('super_admin')),created_at timestamptz not null default now(),primary key(user_id,role));
alter table public.profiles enable row level security;
alter table public.roles enable row level security;
revoke all on public.roles from anon,authenticated;
grant select on public.roles to authenticated;
create policy "Users read own profile" on public.profiles for select to authenticated using(id=(select auth.uid()));
create policy "Users update own profile" on public.profiles for update to authenticated using(id=(select auth.uid())) with check(id=(select auth.uid()));
create policy "Users read own roles" on public.roles for select to authenticated using(user_id=(select auth.uid()));
create or replace function public.create_new_user_profile() returns trigger language plpgsql security definer set search_path = '' as $$ begin insert into public.profiles(id) values(new.id) on conflict do nothing;return new;end;$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.create_new_user_profile();
