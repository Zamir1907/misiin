-- Misiin Stage 5. Execute after 0001 and 0002. PostgreSQL 15+.
create table if not exists public.missions (
 id uuid primary key default gen_random_uuid(), slug text not null unique, title text not null,
 category text not null, difficulty text not null check(difficulty in ('Mudah','Menengah','Sulit')),
 description text not null, objective text not null, issuer text not null,
 reward integer not null check(reward between 0 and 100000000), duration_minutes integer not null check(duration_minutes>0),
 deadline timestamptz not null, quota integer not null check(quota>0),
 requirements jsonb not null default '[]', instructions jsonb not null default '[]',
 materials jsonb not null default '[]', example_result text not null, review_criteria jsonb not null default '[]',
 revision_limit integer not null default 1 check(revision_limit between 0 and 3),
 submission_type text not null check(submission_type in ('text','url','file','screenshot')),
 status text not null default 'draft' check(status in ('draft','published','archived')),
 plus_only boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table if not exists public.mission_claims (
 id uuid primary key default gen_random_uuid(), mission_id uuid not null references public.missions(id),
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'claimed' check(status in ('claimed','submitted','in_review','revision_requested','approved','rejected','expired')),
 claimed_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(mission_id,user_id));
create table if not exists public.mission_submissions (
 id uuid primary key default gen_random_uuid(), claim_id uuid not null references public.mission_claims(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 answer text not null default '', result_url text, file_path text,
 is_draft boolean not null default true, submitted_at timestamptz,
 updated_at timestamptz not null default now(), unique(claim_id));
create table if not exists public.bookmarks (
 user_id uuid not null references auth.users(id) on delete cascade,
 mission_id uuid not null references public.missions(id) on delete cascade,
 created_at timestamptz not null default now(),primary key(user_id,mission_id));
create index if not exists missions_search_idx on public.missions(status,category,difficulty,deadline);
create index if not exists mission_claims_user_idx on public.mission_claims(user_id,status);
create index if not exists submissions_user_idx on public.mission_submissions(user_id);
create or replace function public.misiin_is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.roles where user_id=(select auth.uid()) and role='super_admin'); $$;
revoke all on function public.misiin_is_admin() from public,anon;
grant execute on function public.misiin_is_admin() to authenticated;
-- Membership table introduced here solely for gating; paid activation comes in stage 7.
create table if not exists public.memberships (
 user_id uuid primary key references auth.users(id) on delete cascade,
 tier text not null check(tier in ('free','plus_lifetime')) default 'free',
 status text not null check(status in ('active','inactive')) default 'inactive',
 activated_at timestamptz);
create or replace function public.misiin_has_plus(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships where user_id=p_user and tier='plus_lifetime' and status='active'); $$;
revoke all on function public.misiin_has_plus(uuid) from public,anon;
grant execute on function public.misiin_has_plus(uuid) to authenticated;
alter table public.missions enable row level security;
alter table public.mission_claims enable row level security;
alter table public.mission_submissions enable row level security;
alter table public.bookmarks enable row level security;
alter table public.memberships enable row level security;
revoke all on public.missions,public.mission_claims,public.mission_submissions,public.bookmarks,public.memberships from anon,authenticated;
grant select on public.missions,public.mission_claims,public.mission_submissions,public.bookmarks,public.memberships to authenticated;
grant insert,delete on public.bookmarks to authenticated;
grant insert,update,delete on public.missions to authenticated;
drop policy if exists missions_read on public.missions;
create policy missions_read on public.missions for select to authenticated using(status='published' or public.misiin_is_admin());
drop policy if exists missions_admin_write on public.missions;
create policy missions_admin_write on public.missions for all to authenticated using(public.misiin_is_admin()) with check(public.misiin_is_admin());
drop policy if exists claims_read on public.mission_claims;
create policy claims_read on public.mission_claims for select to authenticated using(user_id=(select auth.uid()) or public.misiin_is_admin());
drop policy if exists submissions_read on public.mission_submissions;
create policy submissions_read on public.mission_submissions for select to authenticated using(user_id=(select auth.uid()) or public.misiin_is_admin());
drop policy if exists bookmarks_own on public.bookmarks;
create policy bookmarks_own on public.bookmarks for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists memberships_own_read on public.memberships;
create policy memberships_own_read on public.memberships for select to authenticated using(user_id=(select auth.uid()) or public.misiin_is_admin());
-- Claims and submissions are exclusively modified through authenticated RPCs.
create or replace function public.claim_mission(p_mission uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid(); v_m public.missions%rowtype; v_id uuid; v_count integer;
begin
 if v_user is null then raise exception 'Login diperlukan'; end if;
 select * into v_m from public.missions where id=p_mission for update;
 if not found or v_m.status<>'published' then raise exception 'Misi tidak tersedia'; end if;
 if v_m.deadline<=now() then raise exception 'Deadline telah berlalu'; end if;
 if v_m.plus_only and not public.misiin_has_plus(v_user) then raise exception 'Misi ini memerlukan Misiin Plus'; end if;
 select id into v_id from public.mission_claims where mission_id=p_mission and user_id=v_user;
 if v_id is not null then return v_id; end if;
 select count(*) into v_count from public.mission_claims where mission_id=p_mission;
 if v_count>=v_m.quota then raise exception 'Kuota penuh'; end if;
 insert into public.mission_claims(mission_id,user_id) values(p_mission,v_user) returning id into v_id;
 return v_id;
end $$;
create or replace function public.save_mission_answer(p_claim uuid,p_answer text,p_url text default null,p_path text default null,p_submit boolean default false)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid(); v_claim public.mission_claims%rowtype; v_deadline timestamptz; v_id uuid; v_existing boolean;
begin
 if v_user is null then raise exception 'Login diperlukan'; end if;
 select * into v_claim from public.mission_claims where id=p_claim and user_id=v_user for update;
 if not found then raise exception 'Pengambilan misi tidak ditemukan'; end if;
 if v_claim.status not in ('claimed','revision_requested') then raise exception 'Jawaban tidak dapat diubah pada status ini'; end if;
 select deadline into v_deadline from public.missions where id=v_claim.mission_id;
 if v_deadline<=now() then raise exception 'Deadline telah berlalu'; end if;
 if length(coalesce(p_answer,''))>20000 then raise exception 'Jawaban terlalu panjang'; end if;
 if p_url is not null and (length(p_url)>2000 or p_url !~ '^https://') then raise exception 'URL harus HTTPS'; end if;
 if p_path is not null and p_path not like v_user::text||'/%' then raise exception 'Lokasi file tidak valid'; end if;
 if p_submit and length(trim(coalesce(p_answer,'')))=0 and p_url is null and p_path is null then raise exception 'Isi jawaban atau bukti sebelum mengirim'; end if;
 select exists(select 1 from public.mission_submissions where claim_id=p_claim) into v_existing;
 insert into public.mission_submissions(claim_id,user_id,answer,result_url,file_path,is_draft,submitted_at)
 values(p_claim,v_user,coalesce(p_answer,''),p_url,p_path,not p_submit,case when p_submit then now() end)
 on conflict(claim_id) do update set answer=excluded.answer,result_url=excluded.result_url,file_path=excluded.file_path,
 is_draft=excluded.is_draft,submitted_at=excluded.submitted_at,updated_at=now()
 returning id into v_id;
 if p_submit then update public.mission_claims set status='submitted',updated_at=now() where id=p_claim; end if;
 return v_id;
end $$;
revoke all on function public.claim_mission(uuid),public.save_mission_answer(uuid,text,text,text,boolean) from public,anon;
grant execute on function public.claim_mission(uuid),public.save_mission_answer(uuid,text,text,text,boolean) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('mission-evidence','mission-evidence',false,5242880,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists mission_evidence_own_read on storage.objects;
drop policy if exists mission_evidence_own_insert on storage.objects;
create policy mission_evidence_own_read on storage.objects for select to authenticated using(bucket_id='mission-evidence' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy mission_evidence_own_insert on storage.objects for insert to authenticated with check(bucket_id='mission-evidence' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Stage 5 does NOT approve submissions or credit rewards; admin review and wallet ledger are later stages.
