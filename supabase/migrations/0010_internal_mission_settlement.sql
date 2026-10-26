-- Internal reward processing. No real-money settlement or withdrawal is performed here.
-- Apply after migrations 0001-0009. Run from a privileged database session.
create table if not exists public.internal_mission_settlement (
 claim_id uuid primary key references public.mission_claims(id) on delete cascade,
 due_at timestamptz not null, settled_at timestamptz
);
alter table public.internal_mission_settlement enable row level security;
revoke all on public.internal_mission_settlement from anon, authenticated;
create or replace function public.queue_internal_mission_settlement()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_delay interval;
begin
 if new.status='submitted' and old.status is distinct from new.status then
  select case m.difficulty when 'Mudah' then interval '5 minutes'
   when 'Menengah' then interval '30 minutes' else interval '2 hours' end
   into v_delay from public.missions m where m.id=new.mission_id;
  insert into public.internal_mission_settlement(claim_id,due_at)
   values(new.id,now()+coalesce(v_delay,interval '30 minutes'))
   on conflict(claim_id) do nothing;
 end if;
 return new;
end $$;
drop trigger if exists queue_internal_settlement on public.mission_claims;
create trigger queue_internal_settlement after update of status on public.mission_claims
 for each row execute function public.queue_internal_mission_settlement();
-- Idempotent settlement: unique(user_id,kind,reference) prevents double credit.
create or replace function public.process_internal_mission_settlements()
returns integer language plpgsql security definer set search_path='' as $$
declare r record; v_count integer:=0;
begin
 for r in
  select q.claim_id,c.user_id,c.mission_id,m.reward
  from public.internal_mission_settlement q
  join public.mission_claims c on c.id=q.claim_id
  join public.missions m on m.id=c.mission_id
  where q.settled_at is null and q.due_at<=now() and c.status='submitted'
  order by q.due_at for update of q skip locked
 loop
  insert into public.wallets(user_id) values(r.user_id) on conflict do nothing;
  insert into public.wallet_ledger(user_id,kind,amount,reference,note)
   values(r.user_id,'mission_reward',r.reward,r.claim_id::text,'Reward internal misi')
   on conflict(user_id,kind,reference) do nothing;
  update public.mission_claims set status='approved',updated_at=now()
   where id=r.claim_id and status='submitted';
  update public.internal_mission_settlement set settled_at=now() where claim_id=r.claim_id;
  v_count:=v_count+1;
 end loop;
 return v_count;
end $$;
revoke all on function public.process_internal_mission_settlements() from public,anon,authenticated;
-- Optional scheduler if pg_cron is available and enabled in Supabase.
-- Run manually in SQL editor once if extension exists:
-- select cron.schedule('misiin-internal-rewards','* * * * *',
--   'select public.process_internal_mission_settlements()');
