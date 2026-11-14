begin;
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade, full_name text not null default 'Paciente', phone text not null default '', role text not null default 'patient' check(role in ('patient','admin')), created_at timestamptz not null default now());
create table public.rooms(id bigint generated always as identity primary key,name text not null unique, specialty text not null check(specialty in ('Medicina general','Odontología','Enfermería')), status text not null default 'unavailable' check(status in ('free','busy','transition','unavailable')), updated_at timestamptz not null default now());
create table public.slots(id uuid primary key default gen_random_uuid(), room_id bigint not null references public.rooms(id), professional text not null check(length(professional) between 2 and 100), specialty text not null check(specialty in ('Medicina general','Odontología','Enfermería')), starts_at timestamptz not null, created_at timestamptz not null default now(), unique(room_id,starts_at),unique(professional,starts_at));
create table public.appointments(id uuid primary key default gen_random_uuid(),slot_id uuid not null references public.slots(id),patient_id uuid not null references public.profiles(id),status text not null default 'booked' check(status in ('booked','confirmed','arrived','completed','cancelled')),checkin_token uuid not null default gen_random_uuid() unique,created_at timestamptz not null default now());
create unique index one_patient_per_slot on public.appointments(slot_id) where status<>'cancelled';
create index patient_appointments on public.appointments(patient_id);
create table public.waiting(id uuid primary key default gen_random_uuid(),patient_id uuid not null references public.profiles(id),specialty text not null check(specialty in ('Medicina general','Odontología','Enfermería')),earliest timestamptz not null,latest timestamptz not null,old_appointment_id uuid references public.appointments(id),created_at timestamptz not null default now(),check(latest>earliest),unique(patient_id,specialty));
create table public.offers(id uuid primary key default gen_random_uuid(),patient_id uuid not null references public.profiles(id),slot_id uuid not null references public.slots(id),old_appointment_id uuid references public.appointments(id),status text not null default 'pending' check(status in ('pending','accepted','declined','expired')),expires_at timestamptz not null,created_at timestamptz not null default now());
create unique index one_offer_per_slot on public.offers(slot_id) where status='pending';
create unique index one_offer_per_patient on public.offers(patient_id) where status='pending';
create table public.audit_log(id bigint generated always as identity primary key,actor_id uuid references public.profiles(id),event text not null,slot_id uuid references public.slots(id),patient_id uuid references public.profiles(id),detail text not null default '',created_at timestamptz not null default now());
create function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.profiles where id=auth.uid() and role='admin')$$;
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$begin insert into public.profiles(id,full_name) values(new.id,left(coalesce(new.raw_user_meta_data->>'full_name',new.raw_user_meta_data->>'name','Paciente'),100));return new;end$$;
create trigger create_profile after insert on auth.users for each row execute function public.handle_new_user();
alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.slots enable row level security;
alter table public.appointments enable row level security;
alter table public.waiting enable row level security;
alter table public.offers enable row level security;
alter table public.audit_log enable row level security;
create policy profiles_read on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy rooms_read on public.rooms for select to authenticated using(true);
create policy slots_read on public.slots for select to authenticated using(true);
create policy appointments_read on public.appointments for select to authenticated using(patient_id=auth.uid() or public.is_admin());
create policy waiting_read on public.waiting for select to authenticated using(patient_id=auth.uid() or public.is_admin());
create policy offers_read on public.offers for select to authenticated using(patient_id=auth.uid() or public.is_admin());
create policy audit_read on public.audit_log for select to authenticated using(public.is_admin());
-- All writes go through validated RPC functions. No client can update roles or tables.
revoke all on public.profiles,public.rooms,public.slots,public.appointments,public.waiting,public.offers,public.audit_log from anon,authenticated;
grant select on public.profiles,public.rooms,public.slots,public.appointments,public.waiting,public.offers,public.audit_log to authenticated;
create function public.save_profile(p_name text,p_phone text) returns void language plpgsql security definer set search_path='' as $$begin if auth.uid() is null then raise exception 'Debes iniciar sesión';end if;if length(trim(p_name)) not between 2 and 100 or length(p_phone)>25 then raise exception 'Datos inválidos';end if;update public.profiles set full_name=trim(p_name),phone=p_phone where id=auth.uid();end$$;
-- One transaction lock serializes scheduling changes; appropriate for a small CESFAM pilot.
create function public.schedule_lock() returns void language sql set search_path='' as $$select pg_catalog.pg_advisory_xact_lock(7418621)$$;
create function public.expire_offers() returns void language sql security definer set search_path='' as $$update public.offers set status='expired' where status='pending' and expires_at<=now()$$;
create function public.available_slots() returns setof public.slots language sql stable security definer set search_path='' as $$select s.* from public.slots s where auth.uid() is not null and s.starts_at>now() and not exists(select 1 from public.appointments a where a.slot_id=s.id and a.status<>'cancelled') and not exists(select 1 from public.offers o where o.slot_id=s.id and o.status='pending' and o.expires_at>now()) order by s.starts_at$$;
-- Private helper: callable only by other definer functions, never by API clients.
create function public.place_booking(p_slot uuid,p_patient uuid,p_old uuid default null) returns uuid language plpgsql security definer set search_path='' as $$declare s public.slots;old_a public.appointments;new_id uuid;begin
 select * into s from public.slots where id=p_slot;if not found or s.starts_at<=now() then raise exception 'Horario no disponible';end if;
 if exists(select 1 from public.appointments where slot_id=p_slot and status<>'cancelled') then raise exception 'El cupo ya fue ocupado';end if;
 if p_old is not null then select * into old_a from public.appointments where id=p_old;if not found or old_a.patient_id<>p_patient or old_a.status not in ('booked','confirmed') then raise exception 'Cita anterior inválida';end if;
 if not exists(select 1 from public.slots os where os.id=old_a.slot_id and os.specialty=s.specialty and os.starts_at>now()) then raise exception 'No puedes cambiar esa cita';end if;end if;
 if exists(select 1 from public.appointments a join public.slots os on os.id=a.slot_id where a.patient_id=p_patient and a.status<>'cancelled' and a.id is distinct from p_old and os.starts_at<s.starts_at+interval '30 minutes' and os.starts_at+interval '30 minutes'>s.starts_at) then raise exception 'Ya existe una cita que coincide con este horario';end if;
 if p_old is not null then update public.appointments set status='cancelled' where id=p_old;insert into public.audit_log(actor_id,event,slot_id,patient_id,detail) values(auth.uid(),'released',old_a.slot_id,p_patient,'Liberación por cambio de hora');end if;
 insert into public.appointments(slot_id,patient_id,status) values(p_slot,p_patient,'confirmed') returning id into new_id;
 insert into public.audit_log(actor_id,event,slot_id,patient_id) values(auth.uid(),'booked',p_slot,p_patient);
 delete from public.waiting where patient_id=p_patient and specialty=s.specialty;return new_id;end$$;
create function public.book_slot(p_slot uuid,p_old uuid default null) returns uuid language plpgsql security definer set search_path='' as $$declare v uuid;begin if auth.uid() is null then raise exception 'Debes iniciar sesión';end if;perform public.schedule_lock();perform public.expire_offers();if exists(select 1 from public.offers where slot_id=p_slot and status='pending') then raise exception 'El cupo tiene una oferta pendiente';end if;v:=public.place_booking(p_slot,auth.uid(),p_old);update public.offers set status='declined' where patient_id=auth.uid() and status='pending';return v;end$$;
create function public.change_appointment(p_id uuid,p_action text,p_reason text default '') returns void language plpgsql security definer set search_path='' as $$declare a public.appointments;s public.slots;begin
 perform public.schedule_lock();select * into a from public.appointments where id=p_id;if not found or not coalesce(a.patient_id=auth.uid() or public.is_admin(),false) then raise exception 'No autorizado';end if;select * into s from public.slots where id=a.slot_id;
 if p_action='confirm' and a.status='booked' and s.starts_at>now() then update public.appointments set status='confirmed' where id=p_id;
 elsif p_action='cancel' and a.status in ('booked','confirmed') and s.starts_at>now() then update public.appointments set status='cancelled' where id=p_id;delete from public.waiting where old_appointment_id=p_id;update public.offers set status='declined' where old_appointment_id=p_id and status='pending';insert into public.audit_log(actor_id,event,slot_id,patient_id,detail) values(auth.uid(),'released',a.slot_id,a.patient_id,left(p_reason,300));
 elsif p_action='complete' and public.is_admin() and a.status='arrived' then update public.appointments set status='completed' where id=p_id;update public.rooms set status='transition',updated_at=now() where id=s.room_id;
 else raise exception 'Acción no permitida para el estado o fecha de la cita';end if;
 insert into public.audit_log(actor_id,event,slot_id,patient_id) values(auth.uid(),p_action,a.slot_id,a.patient_id);end$$;
create function public.join_waitlist(p_specialty text,p_earliest timestamptz,p_latest timestamptz,p_old uuid default null) returns void language plpgsql security definer set search_path='' as $$begin
 if auth.uid() is null then raise exception 'Debes iniciar sesión';end if;perform public.schedule_lock();
 if p_earliest<now() or p_latest<=p_earliest or p_latest>now()+interval '365 days' then raise exception 'Rango de fechas inválido';end if;
 if p_old is not null and not exists(select 1 from public.appointments a join public.slots s on s.id=a.slot_id where a.id=p_old and a.patient_id=auth.uid() and a.status in ('booked','confirmed') and s.specialty=p_specialty and s.starts_at>p_earliest) then raise exception 'Cita anterior incompatible';end if;
 insert into public.waiting(patient_id,specialty,earliest,latest,old_appointment_id) values(auth.uid(),p_specialty,p_earliest,p_latest,p_old) on conflict(patient_id,specialty) do update set earliest=excluded.earliest,latest=excluded.latest,old_appointment_id=excluded.old_appointment_id;
 end$$;
create function public.leave_waitlist(p_id uuid) returns void language plpgsql security definer set search_path='' as $$begin perform public.schedule_lock();delete from public.waiting where id=p_id and patient_id=auth.uid();update public.offers set status='declined' where patient_id=auth.uid() and status='pending';end$$;
create function public.make_offer(p_slot uuid,p_wait uuid) returns uuid language plpgsql security definer set search_path='' as $$declare w public.waiting;s public.slots;o uuid;begin
 if not public.is_admin() then raise exception 'Solo administradores';end if;perform public.schedule_lock();perform public.expire_offers();select * into w from public.waiting where id=p_wait;if not found then raise exception 'Solicitud no disponible';end if;select * into s from public.slots where id=p_slot;
 if not found or s.starts_at<=now() or s.specialty<>w.specialty or s.starts_at<w.earliest or s.starts_at>w.latest then raise exception 'Horario incompatible';end if;
 if w.old_appointment_id is not null and not exists(select 1 from public.appointments a join public.slots os on os.id=a.slot_id where a.id=w.old_appointment_id and a.patient_id=w.patient_id and a.status in ('booked','confirmed') and os.starts_at>s.starts_at) then raise exception 'El cupo no adelanta la cita anterior';end if;
 if exists(select 1 from public.appointments a join public.slots os on os.id=a.slot_id where a.patient_id=w.patient_id and a.status<>'cancelled' and a.id is distinct from w.old_appointment_id and os.starts_at<s.starts_at+interval '30 minutes' and os.starts_at+interval '30 minutes'>s.starts_at) then raise exception 'El paciente ya tiene otra cita en ese horario';end if;
 if exists(select 1 from public.appointments where slot_id=p_slot and status<>'cancelled') then raise exception 'Cupo ocupado';end if;
 insert into public.offers(patient_id,slot_id,old_appointment_id,expires_at) values(w.patient_id,p_slot,w.old_appointment_id,least(now()+interval '24 hours',s.starts_at)) returning id into o;
 insert into public.audit_log(actor_id,event,slot_id,patient_id) values(auth.uid(),'offered',p_slot,w.patient_id);return o;end$$;
create function public.respond_offer(p_id uuid,p_accept boolean) returns void language plpgsql security definer set search_path='' as $$declare o public.offers;begin
 perform public.schedule_lock();perform public.expire_offers();select * into o from public.offers where id=p_id;
 if not found or auth.uid() is null or o.patient_id<>auth.uid() or o.status<>'pending' or o.expires_at<=now() then raise exception 'Oferta no disponible';end if;
 if p_accept then perform public.place_booking(o.slot_id,o.patient_id,o.old_appointment_id);update public.offers set status='accepted' where id=p_id;insert into public.audit_log(actor_id,event,slot_id,patient_id) values(auth.uid(),'reassigned',o.slot_id,o.patient_id);
 else update public.offers set status='declined' where id=p_id;end if;end$$;
create function public.set_room(p_id bigint,p_status text) returns void language plpgsql security definer set search_path='' as $$begin if not public.is_admin() then raise exception 'Solo administradores';end if;update public.rooms set status=p_status,updated_at=now() where id=p_id;if not found then raise exception 'Box no encontrado';end if;insert into public.audit_log(actor_id,event,detail) values(auth.uid(),'room_updated','Box '||p_id||': '||p_status);end$$;
create function public.create_slot(p_room bigint,p_professional text,p_specialty text,p_start timestamptz) returns void language plpgsql security definer set search_path='' as $$begin
 if not public.is_admin() then raise exception 'Solo administradores';end if;perform public.schedule_lock();if p_start<=now() or extract(minute from p_start) not in (0,30) or extract(second from p_start)<>0 then raise exception 'Elige una hora futura en intervalos de 30 minutos';end if;
 if not exists(select 1 from public.rooms where id=p_room and specialty=p_specialty) then raise exception 'Especialidad incompatible con el box';end if;
 if exists(select 1 from public.slots where (room_id=p_room or professional=trim(p_professional)) and starts_at<p_start+interval '30 minutes' and starts_at+interval '30 minutes'>p_start) then raise exception 'Box o profesional ocupado en ese horario';end if;
 insert into public.slots(room_id,professional,specialty,starts_at) values(p_room,trim(p_professional),p_specialty,p_start);end$$;
create function public.register_arrival(p_token uuid) returns void language plpgsql security definer set search_path='' as $$declare a public.appointments;s public.slots;begin
 if not public.is_admin() then raise exception 'Solo recepción puede validar la llegada';end if;perform public.schedule_lock();select * into a from public.appointments where checkin_token=p_token;if not found or a.status not in ('booked','confirmed') then raise exception 'Credencial inválida o ya utilizada';end if;select * into s from public.slots where id=a.slot_id;
 if (s.starts_at at time zone 'America/Santiago')::date<>(now() at time zone 'America/Santiago')::date then raise exception 'La llegada solo se registra el día de la cita';end if;
 update public.appointments set status='arrived' where id=a.id;insert into public.audit_log(actor_id,event,slot_id,patient_id) values(auth.uid(),'arrived',a.slot_id,a.patient_id);end$$;
-- Explicit function allowlist: helpers and trigger cannot be called through the API.
revoke all on function public.is_admin(),public.handle_new_user(),public.save_profile(text,text),public.schedule_lock(),public.expire_offers(),public.available_slots(),public.place_booking(uuid,uuid,uuid),public.book_slot(uuid,uuid),public.change_appointment(uuid,text,text),public.join_waitlist(text,timestamptz,timestamptz,uuid),public.leave_waitlist(uuid),public.make_offer(uuid,uuid),public.respond_offer(uuid,boolean),public.set_room(bigint,text),public.create_slot(bigint,text,text,timestamptz),public.register_arrival(uuid) from public,anon,authenticated;
grant execute on function public.is_admin(),public.save_profile(text,text),public.available_slots(),public.book_slot(uuid,uuid),public.change_appointment(uuid,text,text),public.join_waitlist(text,timestamptz,timestamptz,uuid),public.leave_waitlist(uuid),public.make_offer(uuid,uuid),public.respond_offer(uuid,boolean),public.set_room(bigint,text),public.create_slot(bigint,text,text,timestamptz),public.register_arrival(uuid) to authenticated;
insert into public.rooms(name,specialty,status) values('Box 1','Medicina general','free'),('Box 2','Odontología','unavailable'),('Box 3','Enfermería','transition');
commit;
