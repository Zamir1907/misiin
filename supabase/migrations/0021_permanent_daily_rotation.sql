-- PATCH 0021: migrasi idempotent, tidak menghapus klaim, jawaban, atau saldo.
-- Jalankan setelah migrasi sebelumnya. Backup database sebelum eksekusi.
BEGIN;
ALTER TABLE public.missions ALTER COLUMN deadline DROP NOT NULL;
-- Tanggal lama yang sudah lewat menjadi permanen, hanya untuk misi published.
-- Deadline mendatang tetap dipertahankan sebagai deadline khusus.
UPDATE public.missions SET deadline=NULL, updated_at=now()
 WHERE status='published' AND deadline IS NOT NULL AND deadline < now();
create or replace function public.claim_mission(p_mission uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid(); v_m public.missions%rowtype; v_id uuid; v_count integer;
begin
 if v_user is null then raise exception 'Login diperlukan'; end if;
 select * into v_m from public.missions where id=p_mission for update;
 if not found or v_m.status<>'published' then raise exception 'Misi tidak tersedia'; end if;
 if v_m.deadline is not null and v_m.deadline<=now() then raise exception 'Deadline telah berlalu'; end if;
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
 if v_deadline is not null and v_deadline<=now() then raise exception 'Deadline telah berlalu'; end if;
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

-- Stok nyata: hitung semua klaim historis (tidak di-reset saat hari berganti).
CREATE OR REPLACE FUNCTION public.mission_availability()
RETURNS TABLE(mission_id uuid, remaining bigint, claimed bigint)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
 SELECT m.id, greatest(m.quota::bigint-count(c.id),0::bigint),count(c.id)
 FROM public.missions m LEFT JOIN public.mission_claims c ON c.mission_id=m.id
 WHERE auth.uid() IS NOT NULL AND m.status='published'
 GROUP BY m.id,m.quota;
$$;
REVOKE ALL ON FUNCTION public.mission_availability() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.mission_availability() TO authenticated;
COMMIT;
