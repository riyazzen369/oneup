-- Marketplace (demo). SAMPLE products only; no payments. Not yet applied remotely.
create table if not exists public.products (
  id text primary key,
  dimension text not null,
  category text not null,
  name text not null check (name like 'SAMPLE %'),
  blurb text not null,
  price_sample integer not null default 0,
  consult_only boolean not null default false
);
alter table public.products enable row level security;
create policy "products readable" on public.products for select using (true);

create table if not exists public.market_wishlist (
  user_id uuid not null references auth.users on delete cascade default auth.uid(),
  product_id text not null,
  created_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
create table if not exists public.market_cart (
  user_id uuid not null references auth.users on delete cascade default auth.uid(),
  product_id text not null,
  qty integer not null check (qty between 1 and 10),
  updated_at timestamptz not null default now(),
  primary key (user_id, product_id)
);
create table if not exists public.market_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users on delete cascade default auth.uid(),
  demo_ref text not null,
  lines jsonb not null,
  total_sample integer not null,
  city text,
  status text not null default 'demo_placed',
  created_at timestamptz not null default now()
);
-- Consult-only items can never be carted.
create or replace function public.market_cart_guard() returns trigger language plpgsql as $$
begin
  if exists (select 1 from public.products p where p.id = new.product_id and p.consult_only) then
    raise exception 'consult-only item';
  end if;
  return new;
end $$;
create trigger market_cart_guard before insert or update on public.market_cart for each row execute function public.market_cart_guard();

alter table public.market_wishlist enable row level security;
alter table public.market_cart enable row level security;
alter table public.market_orders enable row level security;
create policy "own wishlist" on public.market_wishlist for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own cart" on public.market_cart for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "own orders read" on public.market_orders for select using (auth.uid() = user_id);
create policy "own orders insert" on public.market_orders for insert with check (auth.uid() = user_id);
