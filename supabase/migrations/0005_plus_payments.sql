-- Stage 7: run after 0004_wallet.sql. Financial verification is server-only.
insert into public.app_settings(key,value) values ('plus_price','10000'::jsonb),('qris_image_url','""'::jsonb) on conflict(key) do nothing;
create table if not exists public.payment_orders (
 id uuid primary key default gen_random_uuid(), order_code text not null unique,
 user_id uuid not null references auth.users(id) on delete cascade,
 amount bigint not null check(amount>0), currency text not null default 'IDR' check(currency='IDR'),
 status text not null default 'pending' check(status in ('pending','paid','expired','cancelled')),
 created_at timestamptz not null default now(), expires_at timestamptz not null,
 user_confirmed_at timestamptz, confirmed_from_ip inet, paid_at timestamptz,
 gateway_reference text unique, gateway_provider text,
 constraint payment_expiry_check check(expires_at>created_at));
create index if not exists payment_orders_user_date on public.payment_orders(user_id,created_at desc);
create unique index if not exists payment_one_pending_per_user on public.payment_orders(user_id) where status='pending';
create table if not exists public.payment_events (
 id uuid primary key default gen_random_uuid(), provider text not null,
 event_id text not null, order_id uuid references public.payment_orders(id),
 created_at timestamptz not null default now(), unique(provider,event_id));
create table if not exists public.audit_logs (
 id uuid primary key default gen_random_uuid(), actor_id uuid references auth.users(id),
 action text not null, entity_id uuid, details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now());
create index if not exists audit_logs_date on public.audit_logs(created_at desc);
do $$ declare t text; begin foreach t in array array['payment_orders','payment_events','audit_logs'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 end loop; end $$;
grant select on public.payment_orders,public.audit_logs to authenticated;
drop policy if exists payment_order_owner on public.payment_orders;
create policy payment_order_owner on public.payment_orders for select to authenticated using(user_id=(select auth.uid()) or public.misiin_is_admin());
drop policy if exists audit_admin_only on public.audit_logs;
create policy audit_admin_only on public.audit_logs for select to authenticated using(public.misiin_is_admin());
-- Harden preexisting membership and bonus helpers: no client may write entitlement or call arbitrary grants.
revoke all on public.memberships from anon,authenticated;
grant select on public.memberships to authenticated;
revoke execute on function public.grant_wallet_bonus(uuid,text,text,text) from public,anon,authenticated;
revoke execute on function public.wallet_setting(text) from public,anon,authenticated;
revoke execute on function public.misiin_has_plus(uuid) from public,anon,authenticated;
grant execute on function public.misiin_has_plus(uuid) to authenticated;
-- Explicit service-only functions, called by Cloudflare using the service role key.
create or replace function public.plus_create_order(p_user uuid)
returns public.payment_orders language plpgsql security definer set search_path='' as $$
declare o public.payment_orders; price bigint;
begin
 if auth.role() <> 'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,17));
 update public.payment_orders set status='expired' where user_id=p_user and status='pending' and expires_at<=now();
 if public.misiin_has_plus(p_user) then raise exception 'Plus sudah aktif'; end if;
 select * into o from public.payment_orders where user_id=p_user and status='pending' limit 1;
 if found then return o; end if;
 price:=public.wallet_setting('plus_price');
 if price<=0 then raise exception 'Harga tidak valid'; end if;
 insert into public.payment_orders(order_code,user_id,amount,expires_at)
 values ('MSN-PLUS-'||to_char(now() at time zone 'UTC','YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),p_user,price,now()+interval '60 minutes') returning * into o;
 return o;
end $$;
create or replace function public.plus_record_user_confirmation(p_user uuid,p_order uuid,p_ip inet)
returns public.payment_orders language plpgsql security definer set search_path='' as $$
declare o public.payment_orders;
begin
 if auth.role()<>'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
 select * into o from public.payment_orders where id=p_order and user_id=p_user for update;
 if not found then raise exception 'Pesanan tidak ditemukan'; end if;
 if o.status='pending' and o.expires_at<=now() then
 update public.payment_orders set status='expired' where id=o.id returning * into o;
 elsif o.status='pending' and now()>=o.created_at+interval '20 seconds' and o.user_confirmed_at is null then
 update public.payment_orders set user_confirmed_at=now(),confirmed_from_ip=p_ip where id=o.id returning * into o;
 elsif o.status='pending' and o.user_confirmed_at is null then raise exception 'Tunggu sebelum konfirmasi'; end if;
 insert into public.audit_logs(actor_id,action,entity_id,details)
 values(p_user,'payment_user_confirmed',p_order,jsonb_build_object('status',o.status));
 return o;
end $$;
create or replace function public.plus_verify_payment(p_order_code text,p_provider text,p_event_id text,p_gateway_reference text,p_paid_amount bigint)
returns boolean language plpgsql security definer set search_path='' as $$
declare o public.payment_orders; inserted uuid;
begin
 if auth.role()<>'service_role' then raise exception 'Forbidden' using errcode='42501'; end if;
 select * into o from public.payment_orders where order_code=p_order_code for update;
 if not found then raise exception 'Order tidak ditemukan'; end if;
 if o.status='paid' then return true; end if;
 if o.status<>'pending' or o.expires_at<=now() then raise exception 'Order tidak aktif'; end if;
 if p_paid_amount<>o.amount or p_gateway_reference is null or length(p_gateway_reference)<4 then raise exception 'Nominal atau referensi tidak valid'; end if;
 insert into public.payment_events(provider,event_id,order_id) values(p_provider,p_event_id,o.id)
 on conflict do nothing returning id into inserted;
 if inserted is null then raise exception 'Event sudah diproses untuk pesanan lain'; end if;
 update public.payment_orders set status='paid',paid_at=now(),gateway_provider=p_provider,gateway_reference=p_gateway_reference where id=o.id;
 insert into public.memberships(user_id,tier,status,activated_at) values(o.user_id,'plus_lifetime','active',now())
 on conflict(user_id) do update set tier='plus_lifetime',status='active',activated_at=coalesce(public.memberships.activated_at,excluded.activated_at);
 perform public.grant_wallet_bonus(o.user_id,'plus_bonus','plus-lifetime','plus_activation_bonus');
 insert into public.audit_logs(actor_id,action,entity_id,details) values(o.user_id,'payment_verified',o.id,jsonb_build_object('provider',p_provider,'event_id',p_event_id));
 return true;
end $$;
revoke all on function public.plus_create_order(uuid) from public,anon,authenticated;
revoke all on function public.plus_record_user_confirmation(uuid,uuid,inet) from public,anon,authenticated;
revoke all on function public.plus_verify_payment(text,text,text,text,bigint) from public,anon,authenticated;
grant execute on function public.plus_create_order(uuid),public.plus_record_user_confirmation(uuid,uuid,inet),public.plus_verify_payment(text,text,text,text,bigint) to service_role;
