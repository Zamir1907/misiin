-- Stage 10, run once after 0007_admin.sql
create table if not exists public.user_settings (
 user_id uuid primary key references auth.users(id) on delete cascade,
 notification_prefs jsonb not null default '{"email_review":true,"email_payment":true,"email_mission":false,"email_announcement":false,"push":false,"in_app":true,"digest":"realtime"}'::jsonb,
 privacy_prefs jsonb not null default '{"visibility":"public","show_region":true,"show_missions":false,"analytics":false,"cookies":false}'::jsonb,
 display_prefs jsonb not null default '{"theme":"light","font_size":"normal","language":"id","timezone":"Asia/Makassar","date_format":"dd/mm/yyyy","currency":"IDR"}'::jsonb,
 updated_at timestamptz not null default now(),
 constraint user_settings_json_types check(jsonb_typeof(notification_prefs)='object' and jsonb_typeof(privacy_prefs)='object' and jsonb_typeof(display_prefs)='object'),
 constraint user_settings_json_size check(length(notification_prefs::text)<3000 and length(privacy_prefs::text)<3000 and length(display_prefs::text)<3000)
);
alter table public.user_settings enable row level security;
revoke all on public.user_settings from anon,authenticated;
grant select,insert,update on public.user_settings to authenticated;
create policy user_settings_owner_select on public.user_settings for select to authenticated using(user_id=(select auth.uid()));
create policy user_settings_owner_insert on public.user_settings for insert to authenticated with check(user_id=(select auth.uid()));
create policy user_settings_owner_update on public.user_settings for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));

-- Only allow known keys and bounded values; never allow arbitrary config keys via RPC.
create table if not exists public.site_faq (
 id uuid primary key default gen_random_uuid(), question text not null check(length(btrim(question)) between 5 and 250),
 answer text not null check(length(btrim(answer)) between 5 and 3000), position integer not null default 0,
 published boolean not null default true, updated_at timestamptz not null default now()
);
create table if not exists public.mission_categories (
 id uuid primary key default gen_random_uuid(), name text not null unique check(length(btrim(name)) between 2 and 70),
 slug text not null unique check(slug ~ '^[a-z0-9-]{2,70}$'), enabled boolean not null default true,
 position integer not null default 0
);

alter table public.site_faq enable row level security;
alter table public.mission_categories enable row level security;
revoke all on public.site_faq,public.mission_categories from anon,authenticated;
grant select on public.site_faq,public.mission_categories to anon,authenticated;
grant insert,update,delete on public.site_faq,public.mission_categories to authenticated;
create policy site_faq_public_read on public.site_faq for select to anon,authenticated using(published or public.misiin_is_admin());
create policy site_faq_admin_insert on public.site_faq for insert to authenticated with check(public.misiin_is_admin());
create policy site_faq_admin_update on public.site_faq for update to authenticated using(public.misiin_is_admin()) with check(public.misiin_is_admin());
create policy site_faq_admin_delete on public.site_faq for delete to authenticated using(public.misiin_is_admin());
create policy mission_categories_public_read on public.mission_categories for select to anon,authenticated using(enabled or public.misiin_is_admin());
create policy mission_categories_admin_insert on public.mission_categories for insert to authenticated with check(public.misiin_is_admin());
create policy mission_categories_admin_update on public.mission_categories for update to authenticated using(public.misiin_is_admin()) with check(public.misiin_is_admin());
create policy mission_categories_admin_delete on public.mission_categories for delete to authenticated using(public.misiin_is_admin());

-- app_settings RLS is read-only for clients; mutations only through restricted RPC.
create or replace function public.admin_update_site_setting(p_key text,p_value jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare v_int bigint; v_str text;
begin
 if auth.uid() is null or not public.misiin_is_admin() then raise exception 'Akses admin ditolak' using errcode='42501'; end if;
 if p_key = any(array['registration_bonus','profile_bonus','plus_activation_bonus','feedback_reward','minimum_withdrawal','plus_price','free_active_limit','plus_active_limit']) then
  if jsonb_typeof(p_value)<>'number' or p_value::text !~ '^[0-9]{1,9}$' then raise exception 'Nominal harus bilangan bulat positif'; end if;
  v_int:=(p_value #>> '{}')::bigint;
  if v_int>100000000 or (p_key='plus_price' and v_int<1000) or (p_key like '%_limit' and (v_int<1 or v_int>100)) then raise exception 'Nilai di luar batas'; end if;
 elsif p_key=any(array['payment_auto_approve','maintenance_mode']) then
  if jsonb_typeof(p_value)<>'boolean' then raise exception 'Nilai harus boolean'; end if;
  if p_key='payment_auto_approve' and p_value='true'::jsonb then raise exception 'Auto approve tanpa verifikasi pembayaran tidak diizinkan'; end if;
 elsif p_key=any(array['site_name','site_logo_url','favicon_url','hero_title','hero_subtitle','qris_image_url','support_hours','contact_email','footer_text','seo_title','seo_description','seo_og_image','active_payment_methods']) then
  if p_key='active_payment_methods' then
   if jsonb_typeof(p_value)<>'array' or jsonb_array_length(p_value)>4 then raise exception 'Metode tidak valid'; end if;
  else
   if jsonb_typeof(p_value)<>'string' or length(p_value #>> '{}')>500 then raise exception 'Teks tidak valid'; end if;
   v_str:=p_value #>> '{}';
   if p_key like '%_url' or p_key in ('favicon_url','seo_og_image') then
    if v_str<>'' and v_str !~ '^https://[^[:space:]]+$' then raise exception 'URL harus HTTPS'; end if;
   end if;
  end if;
 else raise exception 'Pengaturan tidak dikenal'; end if;
 insert into public.app_settings(key,value,updated_at) values(p_key,p_value,now())
 on conflict(key) do update set value=excluded.value,updated_at=now();
 insert into public.audit_logs(actor_id,action,details) values(auth.uid(),'site_setting_updated',jsonb_build_object('key',p_key));
end $$;
revoke all on function public.admin_update_site_setting(text,jsonb) from public,anon;
grant execute on function public.admin_update_site_setting(text,jsonb) to authenticated;
insert into public.app_settings(key,value) values
('site_name','"Misiin"'::jsonb),('hero_title','"Misi kecil, hasil nyata."'::jsonb),
('hero_subtitle','"Temukan pekerjaan digital yang sesuai."'::jsonb),
('maintenance_mode','false'::jsonb),('payment_auto_approve','false'::jsonb),
('free_active_limit','3'::jsonb),('plus_active_limit','10'::jsonb),
('active_payment_methods','["qris"]'::jsonb),('support_hours','"Senin–Jumat, 09.00–17.00"'::jsonb),
('contact_email','""'::jsonb),('footer_text','"Misiin"'::jsonb),
('seo_title','"Misiin — Misi kecil, hasil nyata."'::jsonb),('seo_description','"Platform microtask Misiin"'::jsonb)
on conflict(key) do nothing;
