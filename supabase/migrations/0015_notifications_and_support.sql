-- 0015: publish announcements to user notifications and keep ticket notifications reliable.
-- Run AFTER migrations 0006_support.sql and 0007_admin.sql.
create or replace function public.misiin_announcement_notify()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.status = 'published' and (new.publish_at is null or new.publish_at <= now())
     and (tg_op = 'INSERT' or old.status is distinct from 'published' or old.title is distinct from new.title or old.body is distinct from new.body) then
    insert into public.notifications(user_id,kind,title,body,link)
    select u.id,'announcement',left(new.title,180),left(new.body,2000),'/app.html?page=notifications'
    from auth.users u;
  end if;
  return new;
end $$;
drop trigger if exists misiin_announcement_notification on public.announcements;
create trigger misiin_announcement_notification
 after insert or update of status,title,body,publish_at on public.announcements
 for each row execute function public.misiin_announcement_notify();

-- Ticket submission acknowledgement appears in the user's notification feed.
create or replace function public.misiin_ticket_notify()
returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.notifications(user_id,kind,title,body,link)
 values(new.user_id,'support_ticket','Pengaduan berhasil dikirim',
 'Tiket '||new.ticket_number||' diterima. Kamu bisa memantau balasannya di Pusat Bantuan.',
 '/app.html?page=support&ticket='||new.id::text);
 return new;
end $$;
drop trigger if exists misiin_ticket_notification on public.support_tickets;
create trigger misiin_ticket_notification after insert on public.support_tickets
 for each row execute function public.misiin_ticket_notify();
