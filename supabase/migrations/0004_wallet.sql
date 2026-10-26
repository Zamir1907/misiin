-- Misiin Stage 6. Run AFTER 0001, 0002, 0003. PostgreSQL 15+.
-- Financial settings are integers in IDR. Changes affect future grants only.
create table if not exists public.app_settings (
 key text primary key, value jsonb not null, updated_at timestamptz not null default now(),
 constraint app_settings_key_format check(key ~ '^[a-z][a-z0-9_]{1,63}$')
);
insert into public.app_settings(key,value) values
 ('registration_bonus','5500'::jsonb),('profile_bonus','5000'::jsonb),
 ('plus_activation_bonus','4500'::jsonb),('feedback_reward','2500'::jsonb),
 ('minimum_withdrawal','20000'::jsonb)
on conflict(key) do nothing;
create table if not exists public.wallets (
 user_id uuid primary key references auth.users(id) on delete cascade,
 created_at timestamptz not null default now()
);
create table if not exists public.wallet_ledger (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check(kind in ('registration_bonus','profile_bonus','mission_reward','plus_bonus','withdrawal_hold','withdrawal_refund','adjustment')),
 amount bigint not null check(amount<>0 and abs(amount)<=1000000000),
 reference text not null, note text, created_at timestamptz not null default now(),
 unique(user_id,kind,reference)
);
create index if not exists wallet_ledger_user_date_idx on public.wallet_ledger(user_id,created_at desc);
create table if not exists public.withdrawal_accounts (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 provider text not null, account_number text not null check(account_number ~ '^[0-9]{8,20}$'),
 account_name text not null check(length(btrim(account_name)) between 3 and 120),
 created_at timestamptz not null default now(),
 unique(user_id,provider,account_number)
);
create table if not exists public.withdrawal_requests (
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 account_id uuid not null references public.withdrawal_accounts(id),
 amount bigint not null check(amount>0),
 status text not null default 'pending' check(status in ('pending','processing','paid','rejected','cancelled')),
 created_at timestamptz not null default now(),processed_at timestamptz,admin_note text,
 request_key uuid not null, unique(user_id,request_key)
);
create index if not exists withdrawal_requests_user_date_idx on public.withdrawal_requests(user_id,created_at desc);
create or replace view public.wallet_balances with (security_invoker=true) as
 select w.user_id,coalesce(sum(l.amount),0)::bigint as balance
 from public.wallets w left join public.wallet_ledger l on l.user_id=w.user_id group by w.user_id;
-- RLS and least-privilege grants. No client writes to ledger, wallets, withdrawal requests.
do $$ declare t text; begin
 foreach t in array array['app_settings','wallets','wallet_ledger','withdrawal_accounts','withdrawal_requests'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 end loop;
end $$;
grant select on public.app_settings,public.wallets,public.wallet_ledger,public.withdrawal_requests,public.withdrawal_accounts to authenticated;
grant insert,update,delete on public.withdrawal_accounts to authenticated;
grant select on public.wallet_balances to authenticated;
create policy settings_read on public.app_settings for select to authenticated using(true);
create policy wallet_read on public.wallets for select to authenticated using(user_id=(select auth.uid()));
create policy ledger_read on public.wallet_ledger for select to authenticated using(user_id=(select auth.uid()));
create policy account_read on public.withdrawal_accounts for select to authenticated using(user_id=(select auth.uid()));
create policy account_insert on public.withdrawal_accounts for insert to authenticated with check(user_id=(select auth.uid()));
create policy account_update on public.withdrawal_accounts for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy account_delete on public.withdrawal_accounts for delete to authenticated using(user_id=(select auth.uid()));
create policy withdrawal_read on public.withdrawal_requests for select to authenticated using(user_id=(select auth.uid()));
-- Only a dedicated SECURITY DEFINER function may create ledger credits.
create or replace function public.wallet_setting(p_key text) returns bigint language plpgsql stable security definer set search_path='' as $$
declare v bigint;
begin
 select (value #>> '{}')::bigint into v from public.app_settings where key=p_key;
 if v is null or v<0 or v>100000000 then raise exception 'Pengaturan nominal tidak valid'; end if;
 return v;
end $$;
create or replace function public.grant_wallet_bonus(p_user uuid,p_kind text,p_reference text,p_setting text)
returns boolean language plpgsql security definer set search_path='' as $$
declare v_amount bigint;
begin
 v_amount:=public.wallet_setting(p_setting);
 insert into public.wallets(user_id) values(p_user) on conflict do nothing;
 insert into public.wallet_ledger(user_id,kind,amount,reference)
 values(p_user,p_kind,v_amount,p_reference) on conflict(user_id,kind,reference) do nothing;
 return found;
end $$;
-- Registration bonus for new accounts, in the same transaction as auth.users insertion.
create or replace function public.create_new_user_profile() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.profiles(id) values(new.id) on conflict do nothing;
 perform public.grant_wallet_bonus(new.id,'registration_bonus','signup','registration_bonus');
 return new;
end $$;
-- The existing trigger on_auth_user_created calls this replaced function.
-- Backfill existing accounts; each grant uses the same unique reference.
insert into public.wallets(user_id) select id from auth.users on conflict do nothing;
select public.grant_wallet_bonus(id,'registration_bonus','signup','registration_bonus') from auth.users;
create or replace function public.claim_profile_completion_bonus()
returns boolean language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();p public.profiles%rowtype;
begin
 if v_user is null then raise exception 'Login diperlukan'; end if;
 select * into p from public.profiles where id=v_user for update;
 if not found then raise exception 'Profil tidak ditemukan'; end if;
 if nullif(btrim(coalesce(p.display_name,'')),'') is null
 or p.username is null or p.username !~ '^[a-z0-9_]{3,24}$'
 or length(btrim(coalesce(p.bio,'')))<20 or cardinality(p.skills)<1
 or nullif(btrim(coalesce(p.province,'')),'') is null
 or nullif(btrim(coalesce(p.city,'')),'') is null
 or p.phone is null or p.phone !~ '^08[0-9]{8,11}$' then
 raise exception 'Lengkapi seluruh data profil wajib sebelum klaim'; end if;
 return public.grant_wallet_bonus(v_user,'profile_bonus','profile-complete','profile_bonus');
end $$;
-- The withdrawal request locks the wallet row, serializing all withdrawal requests.
-- A hold immediately debits spendable balance, and is NOT a paid-out transfer.
create or replace function public.request_withdrawal(p_account uuid,p_amount bigint,p_request_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid:=auth.uid();v_id uuid;v_balance bigint;v_min bigint;
begin
 if v_user is null then raise exception 'Login diperlukan'; end if;
 if p_request_key is null then raise exception 'Kunci permintaan wajib diisi'; end if;
 select id into v_id from public.withdrawal_requests where user_id=v_user and request_key=p_request_key;
 if found then return v_id; end if;
 if p_amount is null or p_amount<=0 then raise exception 'Nominal tidak valid'; end if;
 v_min:=public.wallet_setting('minimum_withdrawal');
 if p_amount<v_min then raise exception 'Minimum withdraw Rp%',v_min; end if;
 if not exists(select 1 from public.withdrawal_accounts where id=p_account and user_id=v_user) then raise exception 'Rekening tidak ditemukan'; end if;
 insert into public.wallets(user_id) values(v_user) on conflict do nothing;
 perform 1 from public.wallets where user_id=v_user for update;
 -- Recheck after lock to handle concurrent requests.
 select id into v_id from public.withdrawal_requests where user_id=v_user and request_key=p_request_key;
 if found then return v_id; end if;
 select coalesce(sum(amount),0) into v_balance from public.wallet_ledger where user_id=v_user;
 if v_balance<p_amount then raise exception 'Saldo tidak cukup'; end if;
 insert into public.withdrawal_requests(user_id,account_id,amount,request_key)
 values(v_user,p_account,p_amount,p_request_key) returning id into v_id;
 insert into public.wallet_ledger(user_id,kind,amount,reference,note)
 values(v_user,'withdrawal_hold',-p_amount,v_id::text,'Dana ditahan; menunggu pemeriksaan');
 return v_id;
end $$;
-- Disable direct access to internal functions; only the two user-facing RPCs are callable.
revoke all on function public.wallet_setting(text),public.grant_wallet_bonus(uuid,text,text,text),public.claim_profile_completion_bonus(),public.request_withdrawal(uuid,bigint,uuid) from public,anon,authenticated;
grant execute on function public.claim_profile_completion_bonus(),public.request_withdrawal(uuid,bigint,uuid) to authenticated;
-- SECURITY DEFINER owner must remain trusted postgres role; never expose service role keys.
