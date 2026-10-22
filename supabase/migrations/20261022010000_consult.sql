-- Consult module: new consultant types, SAMPLE consultants, booking status/mode, booking RPCs.
alter table public.consultants drop constraint if exists consultants_type_check;
alter table public.consultants add constraint consultants_type_check
  check (type in ('psychologist','therapist','counsellor','nutritionist','coach'));

-- SAMPLE data only (no real people, credentials or prices). IDs match the app's local list.
insert into public.consultants (id, type, name, bio, dimension_ids, is_sample) values
  ('00000000-0000-4000-9000-000000000001', 'psychologist', 'Sample Psychologist A', 'SAMPLE profile. Placeholder bio for a psychologist offering supportive conversations.', '{1,4}', true),
  ('00000000-0000-4000-9000-000000000002', 'psychologist', 'Sample Psychologist B', 'SAMPLE profile. Placeholder bio for a psychologist.', '{1,5}', true),
  ('00000000-0000-4000-9000-000000000003', 'therapist', 'Sample Therapist A', 'SAMPLE profile. Placeholder bio for a therapist.', '{1,4,5}', true),
  ('00000000-0000-4000-9000-000000000004', 'therapist', 'Sample Therapist B', 'SAMPLE profile. Placeholder bio for a therapist.', '{4,5}', true),
  ('00000000-0000-4000-9000-000000000005', 'nutritionist', 'Sample Nutritionist A', 'SAMPLE profile. Placeholder bio for a nutritionist.', '{2}', true),
  ('00000000-0000-4000-9000-000000000006', 'nutritionist', 'Sample Nutritionist B', 'SAMPLE profile. Placeholder bio for a nutritionist.', '{2}', true),
  ('00000000-0000-4000-9000-000000000007', 'coach', 'Sample Wellness Coach A', 'SAMPLE profile. Placeholder bio for a wellness coach.', '{2,3,8}', true),
  ('00000000-0000-4000-9000-000000000008', 'coach', 'Sample Wellness Coach B', 'SAMPLE profile. Placeholder bio for a wellness coach.', '{6,7,3}', true)
on conflict (id) do update set type = excluded.type, name = excluded.name, bio = excluded.bio,
  dimension_ids = excluded.dimension_ids, is_sample = true;

alter table public.bookings drop constraint if exists bookings_mode_check;
alter table public.bookings add constraint bookings_mode_check check (mode in ('video','audio','chat'));
alter table public.bookings add column if not exists status text not null default 'upcoming'
  check (status in ('upcoming','cancelled'));
-- Allow re-booking a slot after cancellation: only one *upcoming* booking per slot.
alter table public.bookings drop constraint if exists bookings_slot_id_key;
create unique index if not exists bookings_slot_upcoming_uq on public.bookings (slot_id) where status = 'upcoming';
create unique index if not exists slots_consultant_time_uq on public.slots (consultant_id, starts_at);

-- Clients cannot write slots directly (read-only RLS); these RPCs book/cancel atomically for auth.uid().
create or replace function public.book_sample_session(
  p_booking_id uuid, p_consultant_id uuid, p_starts_at timestamptz, p_mode text)
returns void language plpgsql security definer set search_path = public as $$
declare v_slot uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  insert into public.slots (consultant_id, starts_at, is_booked)
    values (p_consultant_id, p_starts_at, true)
    on conflict (consultant_id, starts_at) do update set is_booked = true
      where public.slots.is_booked = false
    returning id into v_slot;
  if v_slot is null then raise exception 'slot already booked'; end if;
  insert into public.bookings (id, user_id, slot_id, mode, status)
    values (p_booking_id, auth.uid(), v_slot, p_mode, 'upcoming');
end $$;

create or replace function public.cancel_my_booking(p_booking_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_slot uuid;
begin
  update public.bookings set status = 'cancelled'
    where id = p_booking_id and user_id = auth.uid() and status = 'upcoming'
    returning slot_id into v_slot;
  if v_slot is not null then update public.slots set is_booked = false where id = v_slot; end if;
end $$;

revoke all on function public.book_sample_session(uuid, uuid, timestamptz, text) from public, anon;
revoke all on function public.cancel_my_booking(uuid) from public, anon;
grant execute on function public.book_sample_session(uuid, uuid, timestamptz, text) to authenticated;
grant execute on function public.cancel_my_booking(uuid) to authenticated;
