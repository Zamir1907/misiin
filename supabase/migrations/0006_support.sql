-- Misiin Stage 8 — run once after 0005_plus_payments.sql
create sequence if not exists public.support_ticket_seq;
revoke all on sequence public.support_ticket_seq from public, anon, authenticated;
create table if not exists public.support_tickets (
 id uuid primary key default gen_random_uuid(),
 ticket_number text not null unique default ('MSN-' || to_char(now() at time zone 'UTC','YYYYMMDD') || '-' || lpad(nextval('public.support_ticket_seq')::text,7,'0')),
 user_id uuid not null references auth.users(id) on delete cascade,
 category text not null check(category in ('Akun','Misi','Pembayaran','Keanggotaan','Withdraw','Masalah Teknis','Lainnya')),
 subject text not null check(char_length(trim(subject)) between 5 and 120),
 description text not null check(char_length(trim(description)) between 15 and 5000),
 status text not null default 'open' check(status in ('open','in_progress','waiting_user','resolved','closed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 resolved_at timestamptz
);
create index if not exists support_tickets_user_date on public.support_tickets(user_id,created_at desc);
create index if not exists support_tickets_status_date on public.support_tickets(status,updated_at desc);
create table if not exists public.support_messages (
 id uuid primary key default gen_random_uuid(),
 ticket_id uuid not null references public.support_tickets(id) on delete cascade,
 sender_id uuid not null references auth.users(id),
 body text not null check(char_length(trim(body)) between 1 and 5000),
 created_at timestamptz not null default now()
);
create index if not exists support_messages_ticket_date on public.support_messages(ticket_id,created_at);
create table if not exists public.support_attachments (
 id uuid primary key default gen_random_uuid(), ticket_id uuid not null references public.support_tickets(id) on delete cascade,
 message_id uuid references public.support_messages(id) on delete cascade,
 uploader_id uuid not null references auth.users(id),
 object_path text not null unique,
 file_name text not null check(char_length(file_name) between 1 and 255),
 mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp','application/pdf')),
 byte_size integer not null check(byte_size between 1 and 5242880),
 created_at timestamptz not null default now()
);
create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null, title text not null, body text not null default '',
 link text, read_at timestamptz, created_at timestamptz not null default now()
);
create index if not exists notifications_user_date on public.notifications(user_id,created_at desc);
-- All data tables enforce RLS. Users may not directly update ticket status, forge admin messages or notifications.
alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
alter table public.support_attachments enable row level security;
alter table public.notifications enable row level security;
revoke all on public.support_tickets,public.support_messages,public.support_attachments,public.notifications from anon,authenticated;
grant select on public.support_tickets,public.support_messages,public.support_attachments,public.notifications to authenticated;
grant update(read_at) on public.notifications to authenticated;
drop policy if exists support_tickets_select on public.support_tickets;
create policy support_tickets_select on public.support_tickets for select to authenticated using(user_id=(select auth.uid()) or public.misiin_is_admin());
drop policy if exists support_messages_select on public.support_messages;
create policy support_messages_select on public.support_messages for select to authenticated using(exists(select 1 from public.support_tickets t where t.id=ticket_id and (t.user_id=(select auth.uid()) or public.misiin_is_admin())));
drop policy if exists support_attachments_select on public.support_attachments;
create policy support_attachments_select on public.support_attachments for select to authenticated using(exists(select 1 from public.support_tickets t where t.id=ticket_id and (t.user_id=(select auth.uid()) or public.misiin_is_admin())));
drop policy if exists notifications_select on public.notifications;
create policy notifications_select on public.notifications for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists notifications_mark_read on public.notifications;
create policy notifications_mark_read on public.notifications for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
-- Privileged RPCs. No client write grants on support tables.
create or replace function public.support_create_ticket(p_category text,p_subject text,p_description text)
returns public.support_tickets language plpgsql security definer set search_path='' as $$
declare t public.support_tickets;
begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501'; end if;
 insert into public.support_tickets(user_id,category,subject,description) values(auth.uid(),trim(p_category),trim(p_subject),trim(p_description)) returning * into t;
 return t;
end $$;
create or replace function public.support_reply(p_ticket uuid,p_body text)
returns public.support_messages language plpgsql security definer set search_path='' as $$
declare t public.support_tickets; m public.support_messages; admin_user boolean;
begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501'; end if;
 select * into t from public.support_tickets where id=p_ticket for update;
 if not found then raise exception 'Tiket tidak ditemukan'; end if;
 admin_user:=public.misiin_is_admin();
 if t.user_id<>auth.uid() and not admin_user then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if t.status='closed' then raise exception 'Tiket ditutup'; end if;
 insert into public.support_messages(ticket_id,sender_id,body) values(p_ticket,auth.uid(),trim(p_body)) returning * into m;
 update public.support_tickets set status=case when admin_user then 'waiting_user' else 'open' end,updated_at=now() where id=p_ticket;
 if admin_user and t.user_id<>auth.uid() then
 insert into public.notifications(user_id,kind,title,body,link) values(t.user_id,'support_reply','Balasan tiket '||t.ticket_number,'Tim bantuan telah membalas tiketmu.','/app.html?page=support&ticket='||p_ticket::text);
 end if;
 return m;
end $$;
create or replace function public.support_admin_status(p_ticket uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare t public.support_tickets;
begin
 if not public.misiin_is_admin() then raise exception 'Akses admin diperlukan' using errcode='42501'; end if;
 if p_status not in ('open','in_progress','waiting_user','resolved','closed') then raise exception 'Status tidak valid'; end if;
 update public.support_tickets set status=p_status,updated_at=now(),resolved_at=case when p_status='resolved' then now() else null end where id=p_ticket returning * into t;
 if not found then raise exception 'Tiket tidak ditemukan'; end if;
 insert into public.notifications(user_id,kind,title,body,link) values(t.user_id,'support_status','Status tiket '||t.ticket_number,'Status terbaru: '||p_status,'/app.html?page=support&ticket='||p_ticket::text);
 insert into public.audit_logs(actor_id,action,entity_id,details) values(auth.uid(),'support_status_changed',p_ticket,jsonb_build_object('status',p_status));
end $$;
-- Storage bucket is private. Policies also check ticket ownership; path = ticket UUID / user UUID / random filename.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('support-attachments','support-attachments',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists support_storage_read on storage.objects;
create policy support_storage_read on storage.objects for select to authenticated using(bucket_id='support-attachments' and exists(
 select 1 from public.support_tickets t where t.id=case when split_part(name,'/',1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then split_part(name,'/',1)::uuid else null end and (t.user_id=(select auth.uid()) or public.misiin_is_admin())
));
drop policy if exists support_storage_insert on storage.objects;
create policy support_storage_insert on storage.objects for insert to authenticated with check(bucket_id='support-attachments' and (storage.foldername(name))[2]=(select auth.uid())::text and exists(
 select 1 from public.support_tickets t where t.id=case when split_part(name,'/',1) ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then split_part(name,'/',1)::uuid else null end and (t.user_id=(select auth.uid()) or public.misiin_is_admin()) and t.status<>'closed'
));
-- Register metadata only for an existing upload, in the current ticket and uploader folder.
create or replace function public.support_register_attachment(p_ticket uuid,p_message uuid,p_path text,p_filename text,p_mime text,p_size integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare attachment_id uuid; t public.support_tickets;
begin
 if auth.uid() is null then raise exception 'Login diperlukan' using errcode='42501'; end if;
 select * into t from public.support_tickets where id=p_ticket;
 if not found or (t.user_id<>auth.uid() and not public.misiin_is_admin()) or t.status='closed' then raise exception 'Akses ditolak' using errcode='42501'; end if;
 if split_part(p_path,'/',1)<>p_ticket::text or split_part(p_path,'/',2)<>auth.uid()::text then raise exception 'Path tidak valid'; end if;
 if p_message is not null and not exists(select 1 from public.support_messages where id=p_message and ticket_id=p_ticket and sender_id=auth.uid()) then raise exception 'Pesan tidak valid'; end if;
 if not exists(select 1 from storage.objects where bucket_id='support-attachments' and name=p_path and owner_id=auth.uid()::text) then raise exception 'Lampiran belum diunggah'; end if;
 insert into public.support_attachments(ticket_id,message_id,uploader_id,object_path,file_name,mime_type,byte_size)
 values(p_ticket,p_message,auth.uid(),p_path,p_filename,p_mime,p_size) returning id into attachment_id;
 return attachment_id;
end $$;
revoke execute on function public.support_create_ticket(text,text,text),public.support_reply(uuid,text),public.support_admin_status(uuid,text),public.support_register_attachment(uuid,uuid,text,text,text,integer) from public,anon;
grant execute on function public.support_create_ticket(text,text,text),public.support_reply(uuid,text),public.support_admin_status(uuid,text),public.support_register_attachment(uuid,uuid,text,text,text,integer) to authenticated;
