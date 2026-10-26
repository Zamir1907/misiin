-- Misiin Stage 9. Run ONCE after 0006_support.sql.
-- Admin writes are mediated by SECURITY DEFINER functions with auth.uid() role checks.
create table if not exists public.mission_reviews (
 id uuid primary key default gen_random_uuid(), claim_id uuid not null references public.mission_claims(id),
 submission_id uuid not null references public.mission_submissions(id), reviewer_id uuid not null references auth.users(id),
 decision text not null check(decision in ('approved','rejected','revision_requested')),
 reason text, created_at timestamptz not null default now(),
 check(decision='approved' or length(btrim(coalesce(reason,'')))>=5)
);
create index if not exists mission_reviews_claim_date on public.mission_reviews(claim_id,created_at desc);
create table if not exists public.announcements (
 id uuid primary key default gen_random_uuid(), title text not null check(length(btrim(title)) between 5 and 120),
 body text not null check(length(btrim(body)) between 5 and 5000),
 status text not null default 'draft' check(status in ('draft','published','archived')),
 publish_at timestamptz, created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table if not exists public.user_restrictions (
 user_id uuid primary key references auth.users(id) on delete cascade,
 suspended boolean not null default false, reason text, updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
-- Restrict data access and protect from direct browser mutations.
alter table public.mission_reviews enable row level security;
alter table public.announcements enable row level security;
alter table public.user_restrictions enable row level security;
revoke all on public.mission_reviews,public.announcements,public.user_restrictions from anon,authenticated;
grant select on public.mission_reviews,public.announcements,public.user_restrictions to authenticated;
create policy reviews_select on public.mission_reviews for select to authenticated using(
 public.misiin_is_admin() or exists(select 1 from public.mission_claims c where c.id=claim_id and c.user_id=(select auth.uid())));
create policy announcements_select on public.announcements for select to authenticated using(
 public.misiin_is_admin() or (status='published' and (publish_at is null or publish_at<=now())));
create policy restrictions_select on public.user_restrictions for select to authenticated using(public.misiin_is_admin() or user_id=(select auth.uid()));
-- Existing tables: grant admin read under RLS, without weakening owner checks.
create policy admin_profiles_read on public.profiles for select to authenticated using(public.misiin_is_admin());
create policy admin_wallets_read on public.wallets for select to authenticated using(public.misiin_is_admin());
create policy admin_ledger_read on public.wallet_ledger for select to authenticated using(public.misiin_is_admin());
create policy admin_withdrawals_read on public.withdrawal_requests for select to authenticated using(public.misiin_is_admin());
create policy admin_withdraw_accounts_read on public.withdrawal_accounts for select to authenticated using(public.misiin_is_admin());
-- Add admin metadata to audit logs, without changing previous event writers.
alter table public.audit_logs add column if not exists ip inet;
alter table public.audit_logs add column if not exists user_agent text;
create or replace function public.admin_assert() returns void language plpgsql security definer set search_path='' as $$
begin if auth.uid() is null or not public.misiin_is_admin() then raise exception 'Akses admin diperlukan' using errcode='42501'; end if; end $$;
revoke all on function public.admin_assert() from public,anon,authenticated;
create or replace function public.admin_log(p_action text,p_entity uuid,p_details jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path='' as $$
begin perform public.admin_assert();
 insert into public.audit_logs(actor_id,action,entity_id,details) values(auth.uid(),p_action,p_entity,coalesce(p_details,'{}'::jsonb)); end $$;
revoke all on function public.admin_log(text,uuid,jsonb) from public,anon,authenticated;
-- Review, grant once, notify. Lock claim to serialize competing reviews.
create or replace function public.admin_review_submission(p_claim uuid,p_decision text,p_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare c public.mission_claims; s public.mission_submissions; v_reward bigint; v_count integer;
begin
 perform public.admin_assert();
 if p_decision not in ('approved','rejected','revision_requested') then raise exception 'Keputusan tidak valid'; end if;
 if p_decision<>'approved' and length(btrim(coalesce(p_reason,'')))<5 then raise exception 'Alasan minimal 5 karakter'; end if;
 select * into c from public.mission_claims where id=p_claim for update;
 if not found or c.status not in ('submitted','in_review') then raise exception 'Misi tidak dalam antrean review'; end if;
 select * into s from public.mission_submissions where claim_id=p_claim and is_draft=false;
 if not found then raise exception 'Submission tidak ditemukan'; end if;
 select reward into v_reward from public.missions where id=c.mission_id;
 if p_decision='approved' then
   insert into public.wallets(user_id) values(c.user_id) on conflict do nothing;
   insert into public.wallet_ledger(user_id,kind,amount,reference,note)
   values(c.user_id,'mission_reward',v_reward,p_claim::text,'Persetujuan misi')
   on conflict(user_id,kind,reference) do nothing;
 end if;
 update public.mission_claims set status=p_decision,updated_at=now() where id=p_claim;
 insert into public.mission_reviews(claim_id,submission_id,reviewer_id,decision,reason)
 values(p_claim,s.id,auth.uid(),p_decision,nullif(btrim(coalesce(p_reason,'')),''));
 insert into public.notifications(user_id,kind,title,body,link)
 values(c.user_id,'mission_review','Hasil review misi',p_decision||coalesce(': '||p_reason,''),'/app.html?page=my-missions');
 perform public.admin_log('mission_review',p_claim,jsonb_build_object('decision',p_decision));
end $$;
-- Financial withdrawal decisions; held money is refunded on rejection exactly once.
create or replace function public.admin_withdrawal_decision(p_request uuid,p_status text,p_note text default null)
returns void language plpgsql security definer set search_path='' as $$
declare w public.withdrawal_requests;
begin
 perform public.admin_assert();
 if p_status not in ('processing','paid','rejected') then raise exception 'Status tidak valid'; end if;
 if p_status='rejected' and length(btrim(coalesce(p_note,'')))<5 then raise exception 'Alasan minimal 5 karakter'; end if;
 select * into w from public.withdrawal_requests where id=p_request for update;
 if not found or w.status not in ('pending','processing') then raise exception 'Status permintaan tidak dapat diubah'; end if;
 if p_status='processing' and w.status<>'pending' then raise exception 'Sudah diproses'; end if;
 if p_status='paid' and w.status<>'processing' then raise exception 'Tandai diproses terlebih dahulu'; end if;
 if p_status='rejected' then
   insert into public.wallet_ledger(user_id,kind,amount,reference,note)
   values(w.user_id,'withdrawal_refund',w.amount,w.id::text,'Pengembalian dana withdraw ditolak')
   on conflict(user_id,kind,reference) do nothing;
 end if;
 update public.withdrawal_requests set status=p_status,admin_note=p_note,
 processed_at=case when p_status in ('paid','rejected') then now() else processed_at end where id=p_request;
 insert into public.notifications(user_id,kind,title,body,link)
 values(w.user_id,'withdrawal_status','Status pencairan',p_status||coalesce(': '||p_note,''),'/app.html?page=wallet');
 perform public.admin_log('withdrawal_'||p_status,p_request,jsonb_build_object('note',p_note));
end $$;
-- Membership cannot be granted manually without verified payment; admin may only inspect.
create or replace function public.admin_set_user_restriction(p_user uuid,p_suspended boolean,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
begin perform public.admin_assert();
 if p_user=auth.uid() then raise exception 'Tidak dapat membatasi akun sendiri'; end if;
 if not exists(select 1 from auth.users where id=p_user) then raise exception 'Akun tidak ditemukan'; end if;
 insert into public.user_restrictions(user_id,suspended,reason,updated_by)
 values(p_user,p_suspended,left(coalesce(p_reason,''),500),auth.uid())
 on conflict(user_id) do update set suspended=excluded.suspended,reason=excluded.reason,updated_at=now(),updated_by=excluded.updated_by;
 perform public.admin_log('user_restriction',p_user,jsonb_build_object('suspended',p_suspended));
end $$;
create or replace function public.admin_upsert_announcement(p_id uuid,p_title text,p_body text,p_status text,p_publish_at timestamptz default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin perform public.admin_assert();
 if p_status not in ('draft','published','archived') then raise exception 'Status tidak valid'; end if;
 if p_id is null then
 insert into public.announcements(title,body,status,publish_at,created_by)
 values(btrim(p_title),btrim(p_body),p_status,p_publish_at,auth.uid()) returning id into v_id;
 else
 update public.announcements set title=btrim(p_title),body=btrim(p_body),status=p_status,publish_at=p_publish_at,updated_at=now()
 where id=p_id returning id into v_id;
 if v_id is null then raise exception 'Pengumuman tidak ditemukan'; end if;
 end if;
 perform public.admin_log('announcement_upsert',v_id,jsonb_build_object('status',p_status));return v_id;
end $$;
-- Audit mission edits via a trigger, including edits made through PostgREST admin RLS.
create or replace function public.admin_mission_audit() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not public.misiin_is_admin() then raise exception 'Admin diperlukan' using errcode='42501'; end if;
 insert into public.audit_logs(actor_id,action,entity_id,details)
 values(auth.uid(),'mission_'||lower(tg_op),coalesce(new.id,old.id),jsonb_build_object('title',coalesce(new.title,old.title)));
 return coalesce(new,old);
end $$;
drop trigger if exists audit_missions_admin on public.missions;
create trigger audit_missions_admin after insert or update or delete on public.missions for each row execute function public.admin_mission_audit();
revoke all on function public.admin_review_submission(uuid,text,text),public.admin_withdrawal_decision(uuid,text,text),
public.admin_set_user_restriction(uuid,boolean,text),public.admin_upsert_announcement(uuid,text,text,text,timestamptz) from public,anon;
grant execute on function public.admin_review_submission(uuid,text,text),public.admin_withdrawal_decision(uuid,text,text),
public.admin_set_user_restriction(uuid,boolean,text),public.admin_upsert_announcement(uuid,text,text,text,timestamptz) to authenticated;
