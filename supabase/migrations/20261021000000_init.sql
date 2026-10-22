-- OneUp full data model (module 1). Row-level security: users only see their own rows.
-- Catalogue tables (dimensions, questions, products, consultants, slots) are read-only to clients.
create extension if not exists pgcrypto;

-- PROFILES ---------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text,
  age_range text check (age_range in ('18–24','25–34','35–44','45–54','55–64','65+')),
  avatar_url text,
  theme text not null default 'system' check (theme in ('light','dark','system')),
  consent_version text,
  consent_at timestamptz,
  created_at timestamptz not null default now()
);

-- CATALOGUE --------------------------------------------------------------
create table public.dimensions (
  id smallint primary key,
  key text unique not null,
  name text not null,
  color_light text not null,
  color_dark text not null,
  sort_order smallint not null
);
insert into public.dimensions values
 (1,'emotional','Emotional','#E5487A','#FF7AA2',1),
 (2,'physical','Physical','#1E88E5','#64B5F6',2),
 (3,'occupational','Occupational','#F57C00','#FFB74D',3),
 (4,'social','Social','#00897B','#4DD0C1',4),
 (5,'spiritual','Spiritual','#7E57C2','#B39DDB',5),
 (6,'intellectual','Intellectual','#C79100','#FFD54F',6),
 (7,'environmental','Environmental','#43A047','#81C784',7),
 (8,'financial','Financial','#3949AB','#8C9EFF',8);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  dimension_id smallint not null references public.dimensions(id),
  text text not null,
  scale_type text not null check (scale_type in ('agreement','frequency')),
  reverse_scored boolean not null default false,
  sort_order smallint not null
);

-- ASSESSMENTS ------------------------------------------------------------
create table public.assessments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  status text not null default 'in_progress' check (status in ('in_progress','completed'))
);

-- value_enc: AES-256 ciphertext produced on device (plain 1–5 never stored server-side).
create table public.answers (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  question_id uuid not null references public.questions(id),
  value_enc text not null,
  answered_at timestamptz not null default now(),
  unique (assessment_id, question_id)
);

create table public.dimension_scores (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references public.assessments(id) on delete cascade,
  dimension_id smallint not null references public.dimensions(id),
  score smallint not null check (score between 0 and 100),
  band text not null check (band in ('needs_attention','developing','thriving')),
  unique (assessment_id, dimension_id)
);

create table public.goals (
  user_id uuid not null references auth.users(id) on delete cascade,
  dimension_id smallint not null references public.dimensions(id),
  target_score smallint not null check (target_score between 0 and 100),
  primary key (user_id, dimension_id)
);

-- MARKETPLACE (SAMPLE data only) -----------------------------------------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('medicine','supplement','lifestyle','book','course')),
  dimension_ids smallint[] not null default '{}',
  title text not null,
  description text,
  price_inr numeric(10,2),
  requires_prescription boolean not null default false,
  is_sample boolean not null default true
);

create table public.consultants (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('therapist','counsellor','coach')),
  name text not null,
  bio text,
  dimension_ids smallint[] not null default '{}',
  is_sample boolean not null default true
);

create table public.slots (
  id uuid primary key default gen_random_uuid(),
  consultant_id uuid not null references public.consultants(id) on delete cascade,
  starts_at timestamptz not null,
  is_booked boolean not null default false
);

create table public.wishlist (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);

create table public.cart_items (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  qty int not null default 1 check (qty > 0),
  primary key (user_id, product_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  total_inr numeric(10,2) not null default 0,
  status text not null default 'placed' check (status in ('placed','paid_placeholder','cancelled')),
  created_at timestamptz not null default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id),
  qty int not null default 1,
  price_inr numeric(10,2) not null
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  slot_id uuid not null unique references public.slots(id),
  mode text not null default 'video' check (mode in ('video','audio')),
  order_id uuid references public.orders(id),
  created_at timestamptz not null default now()
);

-- ROW LEVEL SECURITY -----------------------------------------------------
alter table public.profiles enable row level security;
alter table public.dimensions enable row level security;
alter table public.questions enable row level security;
alter table public.assessments enable row level security;
alter table public.answers enable row level security;
alter table public.dimension_scores enable row level security;
alter table public.goals enable row level security;
alter table public.products enable row level security;
alter table public.consultants enable row level security;
alter table public.slots enable row level security;
alter table public.wishlist enable row level security;
alter table public.cart_items enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.bookings enable row level security;

-- Catalogue: read-only for signed-in users.
create policy "read dimensions" on public.dimensions for select to authenticated using (true);
create policy "read questions" on public.questions for select to authenticated using (true);
create policy "read products" on public.products for select to authenticated using (true);
create policy "read consultants" on public.consultants for select to authenticated using (true);
create policy "read slots" on public.slots for select to authenticated using (true);

-- Own rows only.
create policy "own profile" on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy "own assessments" on public.assessments for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own goals" on public.goals for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own wishlist" on public.wishlist for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own cart" on public.cart_items for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own orders" on public.orders for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own bookings" on public.bookings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Child rows: ownership via parent.
create policy "own answers" on public.answers for all to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id and a.user_id = auth.uid()))
  with check (exists (select 1 from public.assessments a where a.id = assessment_id and a.user_id = auth.uid()));
create policy "own scores" on public.dimension_scores for all to authenticated
  using (exists (select 1 from public.assessments a where a.id = assessment_id and a.user_id = auth.uid()))
  with check (exists (select 1 from public.assessments a where a.id = assessment_id and a.user_id = auth.uid()));
create policy "own order items" on public.order_items for all to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()))
  with check (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()));

-- DELETE MY DATA ---------------------------------------------------------
-- Removes the auth user; all user rows cascade (profiles, assessments→answers/scores,
-- goals, wishlist, cart, orders→order_items, bookings).
create or replace function public.delete_my_data()
returns void language plpgsql security definer set search_path = public, auth as $$
begin
  update public.slots set is_booked = false
   where id in (select slot_id from public.bookings where user_id = auth.uid());
  delete from auth.users where id = auth.uid();
end $$;
revoke all on function public.delete_my_data() from public, anon;
grant execute on function public.delete_my_data() to authenticated;
